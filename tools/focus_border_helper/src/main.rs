#![windows_subsystem = "windows"]

use iced::{
    Renderer, Theme, mouse,
    futures::{SinkExt, Stream, StreamExt, channel::mpsc::channel},
    stream,
    widget::{self, canvas::{self, Path, Stroke}},
    window::{self, settings::PlatformSpecific},
    Color, Point, Rectangle, Size, Task,
    theme::Palette,
};
use serde::Deserialize;
use std::{sync::OnceLock, thread};
use windows::Win32::{
    Foundation::{HWND, LPARAM, LRESULT, WPARAM},
    System::{
        DataExchange::COPYDATASTRUCT,
        LibraryLoader::GetModuleHandleW,
    },
    UI::WindowsAndMessaging::{
        CreateWindowExW, DefWindowProcW, DispatchMessageW, GetMessageW,
        RegisterClassW, TranslateMessage, CW_USEDEFAULT, MSG, WNDCLASSW,
        WM_COPYDATA, WM_DESTROY, WINDOW_EX_STYLE, WINDOW_STYLE,
        PostQuitMessage, GetSystemMetrics, SM_XVIRTUALSCREEN, SM_YVIRTUALSCREEN,
        SM_CXVIRTUALSCREEN, SM_CYVIRTUALSCREEN,
    },
};

const IPC_WINDOW_TITLE: &str = "Harken Focus Border Helper IPC";
const STREAM_CHANNEL_BUFFER_SIZE: usize = 32;

static IPC_SENDER: OnceLock<iced::futures::channel::mpsc::Sender<BorderUpdate>> = OnceLock::new();

#[derive(Debug, Clone, Deserialize)]
struct BorderUpdate {
    visible: u8,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    color: String,
    thickness: f32,
    radius: f32,
}

#[derive(Debug, Clone)]
enum Message {
    BorderUpdate(BorderUpdate),
}

#[derive(Debug, Clone)]
struct BorderState {
    visible: bool,
    bounds: Rectangle,
    color: Color,
    thickness: f32,
    radius: f32,
}

impl Default for BorderState {
    fn default() -> Self {
        Self {
            visible: false,
            bounds: Rectangle::new(Point::new(0.0, 0.0), Size::new(0.0, 0.0)),
            color: Color::from_rgb(0.21, 0.49, 0.78),
            thickness: 4.0,
            radius: 8.0,
        }
    }
}

struct State {
    overlay_window_id: window::Id,
    border: BorderState,
    virtual_origin: Point,
}

fn main() {
    if let Err(error) = iced::daemon(State::new, State::update, State::view)
        .subscription(State::subscription)
        .title(State::title)
        .theme(State::theme)
        .run()
    {
        eprintln!("Helper exited: {error}");
    }
}

impl State {
    fn new() -> (Self, Task<Message>) {
        let (virtual_origin, virtual_size) = virtual_screen_bounds();
        let (overlay_window_id, task) = create_overlay_window(virtual_origin, virtual_size);

        (
            Self {
                overlay_window_id,
                border: BorderState::default(),
                virtual_origin,
            },
            task,
        )
    }

    fn update(&mut self, message: Message) -> Task<Message> {
        match message {
            Message::BorderUpdate(update) => {
                if update.visible != 0 && update.w > 0 && update.h > 0 {
                    let x = (update.x - self.virtual_origin.x as i32) as f32;
                    let y = (update.y - self.virtual_origin.y as i32) as f32;
                    self.border.visible = true;
                    self.border.bounds = Rectangle::new(
                        Point::new(x, y),
                        Size::new(update.w as f32, update.h as f32),
                    );
                    self.border.color = parse_hex_color(&update.color)
                        .unwrap_or(self.border.color);
                    self.border.thickness = update.thickness.max(1.0);
                    self.border.radius = update.radius.max(0.0);
                } else {
                    self.border.visible = false;
                }
            }
        }
        Task::none()
    }

    fn view(&self, window_id: window::Id) -> iced::Element<'_, Message> {
        if window_id != self.overlay_window_id {
            return widget::Space::new().into();
        }

        if !self.border.visible {
            return widget::Space::new().into();
        }

        widget::canvas(BorderCanvas {
            border: self.border.clone(),
        })
        .width(iced::Length::Fill)
        .height(iced::Length::Fill)
        .into()
    }

    fn subscription(_: &Self) -> iced::Subscription<Message> {
        iced::Subscription::run(subscription)
    }

    fn title(_: &Self, _window_id: window::Id) -> String {
        IPC_WINDOW_TITLE.into()
    }

    fn theme(&self, _window_id: window::Id) -> Theme {
        Theme::custom(
            "Transparent overlay theme",
            Palette {
                background: Color::from_rgba(0.0, 0.0, 0.0, 0.0),
                ..Palette::DARK
            },
        )
    }
}

struct BorderCanvas {
    border: BorderState,
}

impl canvas::Program<Message> for BorderCanvas {
    type State = ();

    fn draw(
        &self,
        _state: &Self::State,
        renderer: &Renderer,
        _theme: &Theme,
        bounds: Rectangle,
        _cursor: mouse::Cursor,
    ) -> Vec<canvas::Geometry<Renderer>> {
        let mut frame = canvas::Frame::new(renderer, bounds.size());

        let path = Path::rounded_rectangle(
            self.border.bounds.position(),
            self.border.bounds.size(),
            self.border.radius.into(),
        );

        frame.stroke(
            &path,
            Stroke::default()
                .with_color(self.border.color)
                .with_width(self.border.thickness),
        );

        vec![frame.into_geometry()]
    }
}

fn create_overlay_window(
    virtual_origin: Point,
    virtual_size: Size,
) -> (window::Id, Task<Message>) {
    let (id, task) = window::open(window::Settings {
        decorations: false,
        transparent: true,
        resizable: false,
        closeable: false,
        level: window::Level::AlwaysOnTop,
        position: window::Position::Specific(virtual_origin),
        size: virtual_size,
        platform_specific: PlatformSpecific {
            skip_taskbar: true,
            ..Default::default()
        },
        ..Default::default()
    });

    (id, task.then(window::enable_mouse_passthrough))
}

fn subscription() -> impl Stream<Item = Message> {
    stream::channel(STREAM_CHANNEL_BUFFER_SIZE, async |mut output| {
        let (intermediate_tx, mut intermediate_rx) = channel(100);
        launch_ipc_listener(intermediate_tx);

        while let Some(event) = intermediate_rx.next().await {
            output.send(Message::BorderUpdate(event)).await.ok();
        }
    })
}

fn launch_ipc_listener(tx: iced::futures::channel::mpsc::Sender<BorderUpdate>) {
    if IPC_SENDER.set(tx).is_err() {
        return;
    }

    let _ = thread::Builder::new()
        .name("focus-border-ipc".to_string())
        .spawn(move || unsafe {
            let h_instance = GetModuleHandleW(None).unwrap_or_default();
            let class_name = windows::core::w!("HarkenFocusBorderHelper");
            let window_name = windows::core::w!("Harken Focus Border Helper IPC");

            let wnd_class = WNDCLASSW {
                hInstance: h_instance.into(),
                lpszClassName: class_name,
                lpfnWndProc: Some(ipc_wnd_proc),
                ..Default::default()
            };

            RegisterClassW(&wnd_class);

            let _hwnd = CreateWindowExW(
                WINDOW_EX_STYLE(0),
                class_name,
                window_name,
                WINDOW_STYLE(0),
                CW_USEDEFAULT,
                CW_USEDEFAULT,
                CW_USEDEFAULT,
                CW_USEDEFAULT,
                None,
                None,
                Some(h_instance.into()),
                None,
            );

            let mut message = MSG::default();
            while GetMessageW(&mut message, None, 0, 0).into() {
                let _ = TranslateMessage(&message);
                DispatchMessageW(&message);
            }
        });
}

unsafe extern "system" fn ipc_wnd_proc(
    hwnd: HWND,
    message: u32,
    w_param: WPARAM,
    l_param: LPARAM,
) -> LRESULT {
    match message {
        WM_COPYDATA => {
            let copy_data = l_param.0 as *const COPYDATASTRUCT;
            if copy_data.is_null() {
                return LRESULT(0);
            }
            let data = unsafe {
                std::slice::from_raw_parts(
                    (*copy_data).lpData as *const u8,
                    (*copy_data).cbData as usize,
                )
            };
            match std::str::from_utf8(data) {
                Ok(text) => {
                    let trimmed = text.trim_end_matches('\0');
                    match serde_json::from_str::<BorderUpdate>(trimmed) {
                        Ok(update) => {
                            if let Some(sender) = IPC_SENDER.get() {
                                let mut sender = sender.clone();
                                let _ = sender.try_send(update);
                            }
                        }
                        Err(_) => {}
                    }
                }
                Err(_) => {}
            }
            LRESULT(1)
        }
        WM_DESTROY => {
            unsafe { PostQuitMessage(0); }
            LRESULT(0)
        }
        _ => unsafe { DefWindowProcW(hwnd, message, w_param, l_param) },
    }
}

fn virtual_screen_bounds() -> (Point, Size) {
    unsafe {
        let x = GetSystemMetrics(SM_XVIRTUALSCREEN) as f32;
        let y = GetSystemMetrics(SM_YVIRTUALSCREEN) as f32;
        let w = GetSystemMetrics(SM_CXVIRTUALSCREEN) as f32;
        let h = GetSystemMetrics(SM_CYVIRTUALSCREEN) as f32;
        (Point::new(x, y), Size::new(w, h))
    }
}

fn parse_hex_color(value: &str) -> Option<Color> {
    let trimmed = value.trim().trim_start_matches('#');
    if trimmed.len() != 6 {
        return None;
    }
    let r = u8::from_str_radix(&trimmed[0..2], 16).ok()?;
    let g = u8::from_str_radix(&trimmed[2..4], 16).ok()?;
    let b = u8::from_str_radix(&trimmed[4..6], 16).ok()?;
    Some(Color::from_rgb(r as f32 / 255.0, g as f32 / 255.0, b as f32 / 255.0))
}
