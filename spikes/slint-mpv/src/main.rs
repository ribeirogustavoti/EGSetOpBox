// SPDX-License-Identifier: GPL-3.0-only

use std::{
    cell::RefCell,
    ffi::CStr,
    os::raw::c_void,
    sync::{Arc, Mutex},
    time::Duration,
};

use libmpv2::{
    render::{OpenGLInitParams, RenderContext, RenderParam, RenderParamApiType},
    Mpv,
};

slint::slint! {
    export component AppWindow inherits Window {
        preferred-width: 3840px;
        preferred-height: 2160px;
        background: transparent;

        // Animated bar — moves continuously so Slint redraws every frame.
        in-out property <float> bar-pos: 0.0;
        // Info line shown in the top-left corner.
        in-out property <string> info-text: "fps: 0 | hwdec: ...";

        Rectangle {
            width: 120px;
            height: 10px;
            x: (parent.width - self.width) * root.bar-pos;
            y: (parent.height - self.height) / 2;
            background: white;
            opacity: 0.9;
        }
        Text {
            x: 20px;
            y: 20px;
            text: root.info-text;
            color: white;
            font-size: 36px;
        }
    }
}

// RenderContext is not Send in libmpv2 because it holds a raw pointer.
// We only ever touch it from the rendering thread, always behind the Mutex.
struct CtxWrap(RenderContext);
unsafe impl Send for CtxWrap {}

struct RenderState {
    ctx: CtxWrap,
    frames: u64,
}

// Thread-local slot used by proc_addr_trampoline during RenderContext::new().
thread_local! {
    static PROC_ADDR: RefCell<Option<Box<dyn Fn(&CStr) -> *const c_void>>> =
        RefCell::new(None);
}

unsafe extern "C" fn proc_addr_trampoline(
    _ctx: *mut c_void,
    name: *const std::os::raw::c_char,
) -> *mut c_void {
    PROC_ADDR.with(|slot| {
        slot.borrow()
            .as_ref()
            .map_or(std::ptr::null_mut(), |f| {
                f(unsafe { CStr::from_ptr(name) }) as *mut c_void
            })
    })
}

fn parse_args(args: &[String]) -> (String, String) {
    if args.len() < 2 {
        eprintln!("Usage: {} <video-file> [--hwdec <mode>]", args[0]);
        std::process::exit(1);
    }
    let video_file = args[1].clone();
    let hwdec = args
        .windows(2)
        .find(|w| w[0] == "--hwdec")
        .map(|w| w[1].clone())
        // Default: hwdec mode from M0-12 findings for H.264 1080p.
        // Placeholder until O-04 is resolved; update from Chat Master once available.
        .unwrap_or_else(|| "v4l2m2m-copy".to_string());
    (video_file, hwdec)
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let (video_file, hwdec) = parse_args(&args);

    // ── mpv setup ────────────────────────────────────────────────────────────
    let mpv = Mpv::new().expect("create mpv handle");
    mpv.set_property("vo", "libmpv").expect("set vo=libmpv");
    mpv.set_property("hwdec", hwdec.as_str()).expect("set hwdec");
    mpv.set_property("loop-file", "inf").expect("set loop-file");
    mpv.initialize().expect("initialize mpv");

    // Cast the handle pointer to usize so it can cross the Send boundary
    // in the rendering-notifier closure. libmpv_handle is designed to be
    // accessed from any thread.
    let raw_ctx: usize = unsafe { mpv.ctx.as_ptr() as usize };
    let mpv = Arc::new(mpv);

    // ── Slint window ─────────────────────────────────────────────────────────
    let window = AppWindow::new().expect("create AppWindow");
    let window_weak = window.as_weak();

    let render_state: Arc<Mutex<Option<RenderState>>> = Arc::new(Mutex::new(None));
    let frame_total: Arc<Mutex<u64>> = Arc::new(Mutex::new(0));

    // ── Rendering notifier ───────────────────────────────────────────────────
    {
        let render_state = render_state.clone();
        let frame_total_n = frame_total.clone();
        let window_weak_n = window_weak.clone();

        window
            .window()
            .set_rendering_notifier(move |state, api| match state {
                slint::RenderingState::RenderingSetup => {
                    let slint::GraphicsAPI::NativeOpenGL { get_proc_address } = api else {
                        return;
                    };

                    // Stash the Slint proc-address function in a thread-local
                    // so the C trampoline can reach it during RenderContext::new.
                    PROC_ADDR.with(|slot| {
                        *slot.borrow_mut() = Some(Box::new(|name: &CStr| {
                            get_proc_address(name)
                        }));
                    });

                    let handle =
                        unsafe { &mut *(raw_ctx as *mut libmpv2::mpv_handle) };

                    let ww = window_weak_n.clone();
                    let ctx = unsafe {
                        RenderContext::new(
                            handle,
                            vec![
                                RenderParam::ApiType(RenderParamApiType::OpenGl),
                                RenderParam::InitParams(OpenGLInitParams {
                                    get_proc_address: proc_addr_trampoline,
                                    ctx: std::ptr::null_mut(),
                                }),
                                RenderParam::UpdateCallback(Box::new(move || {
                                    let _ = slint::invoke_from_event_loop({
                                        let ww = ww.clone();
                                        move || {
                                            if let Some(w) = ww.upgrade() {
                                                w.window().request_redraw();
                                            }
                                        }
                                    });
                                })),
                            ],
                        )
                    }
                    .expect("create mpv RenderContext");

                    // No longer need the proc-address function.
                    PROC_ADDR.with(|slot| *slot.borrow_mut() = None);

                    *render_state.lock().unwrap() = Some(RenderState {
                        ctx: CtxWrap(ctx),
                        frames: 0,
                    });
                }

                slint::RenderingState::BeforeRendering => {
                    let slint::GraphicsAPI::NativeOpenGL { .. } = api else {
                        return;
                    };
                    if let Some(rs) = render_state.lock().unwrap().as_mut() {
                        if let Some(w) = window_weak_n.upgrade() {
                            let s = w.window().size();
                            // Render the video frame into FBO 0 at the
                            // window's physical size; Slint draws the
                            // overlay on top immediately after.
                            unsafe {
                                rs.ctx
                                    .0
                                    .render(0, s.width as i32, s.height as i32, true)
                                    .ok();
                            }
                        }
                    }
                }

                slint::RenderingState::AfterRendering => {
                    if let Some(rs) = render_state.lock().unwrap().as_mut() {
                        rs.frames += 1;
                        *frame_total_n.lock().unwrap() = rs.frames;
                    }
                }

                slint::RenderingState::RenderingTeardown => {
                    *render_state.lock().unwrap() = None;
                }

                _ => {}
            })
            .expect("set_rendering_notifier");
    }

    // ── FPS display timer (1 s interval) ────────────────────────────────────
    // Prints one line to stderr every second; also updates the on-screen text.
    let mpv_fps = mpv.clone();
    let window_weak_fps = window_weak.clone();
    let frame_total_fps = frame_total.clone();
    let mut prev_frames: u64 = 0;
    let _fps_timer = {
        let t = slint::Timer::default();
        t.start(
            slint::TimerMode::Repeated,
            Duration::from_secs(1),
            move || {
                let total = *frame_total_fps.lock().unwrap();
                let fps = total.saturating_sub(prev_frames);
                prev_frames = total;

                let hwdec_cur = mpv_fps
                    .get_property::<String>("hwdec-current")
                    .unwrap_or_else(|_| "?".into());
                let drops =
                    mpv_fps.get_property::<i64>("frame-drop-count").unwrap_or(0);
                let dec_drops = mpv_fps
                    .get_property::<i64>("decoder-frame-drop-count")
                    .unwrap_or(0);
                let size = window_weak_fps
                    .upgrade()
                    .map(|w| {
                        let s = w.window().size();
                        format!("{}x{}", s.width, s.height)
                    })
                    .unwrap_or_else(|| "?".into());

                eprintln!(
                    "fps={fps} hwdec={hwdec_cur} drops={drops} \
                     dec-drops={dec_drops} size={size}"
                );

                if let Some(w) = window_weak_fps.upgrade() {
                    w.set_info_text(
                        format!("fps: {fps} | hwdec: {hwdec_cur}").into(),
                    );
                }
            },
        );
        t
    };

    // ── Bar animation timer (≈60 fps) ────────────────────────────────────────
    // Moves the bar across the screen to force continuous repaints.
    let window_weak_bar = window_weak.clone();
    let _bar_timer = {
        let t = slint::Timer::default();
        t.start(
            slint::TimerMode::Repeated,
            Duration::from_millis(16),
            move || {
                if let Some(w) = window_weak_bar.upgrade() {
                    let pos = (w.get_bar_pos() + 0.004_f32).rem_euclid(1.0);
                    w.set_bar_pos(pos);
                }
            },
        );
        t
    };

    // ── Load video and run ───────────────────────────────────────────────────
    mpv.command("loadfile", &[video_file.as_str(), "replace"])
        .expect("loadfile");

    window.run().expect("slint event loop");
}
