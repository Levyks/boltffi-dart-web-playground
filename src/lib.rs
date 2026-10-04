use std::sync::Arc;

use boltffi::*;

#[data]
#[derive(Clone)]
pub struct Message {
    pub text: String,
    pub values: Vec<i32>,
}

#[data]
pub struct Failure {
    pub code: u32,
    pub message: String,
}

impl From<UnexpectedFfiCallbackError> for Failure {
    fn from(error: UnexpectedFfiCallbackError) -> Self {
        Self {
            code: 99,
            message: error.to_string(),
        }
    }
}

#[data]
pub enum Choice {
    Empty,
    Number(i32),
    Text(String),
}

#[export]
pub fn add(left: i32, right: i32) -> i32 {
    left + right
}

#[export]
pub fn greeting(#[boltffi::default("world")] name: String) -> String {
    format!("Hello, {name}!")
}

#[export]
pub fn echo_message(value: Message) -> Message {
    value
}

#[data]
#[derive(Clone, Copy)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}

#[export]
pub fn update_point(value: &mut Point) {
    value.x += 10.0;
    value.y += 20.0;
}

#[export]
pub fn update_then_fail(value: &mut Point) -> Result<(), Failure> {
    value.x += 1.0;
    Err(Failure {
        code: 8,
        message: "updated before error".into(),
    })
}

#[export]
pub fn echo_choice(value: Choice) -> Choice {
    value
}

#[export]
pub fn echo_bytes(value: Vec<u8>) -> Vec<u8> {
    value
}

#[export]
pub fn echo_bools(value: Vec<bool>) -> Vec<bool> {
    value
}

#[export]
pub fn echo_longs(value: Vec<i64>) -> Vec<i64> {
    value
}

#[export]
pub fn optional_value(found: bool) -> Option<i32> {
    found.then_some(42)
}

#[export]
pub fn divide(left: i32, right: i32) -> Result<i32, String> {
    left.checked_div(right)
        .ok_or_else(|| "invalid division".into())
}

#[export]
pub fn validate(value: i32) -> Result<i32, Failure> {
    if value < 0 {
        Err(Failure {
            code: 7,
            message: "negative value".into(),
        })
    } else {
        Ok(value)
    }
}

#[export]
pub async fn async_add(left: i32, right: i32) -> i32 {
    left + right
}

#[export]
pub async fn async_validate(value: i32) -> Result<i32, Failure> {
    validate(value)
}

#[export]
pub async fn async_optional(found: bool) -> Option<i32> {
    optional_value(found)
}

#[export]
pub async fn wait_forever(on_started: impl StartSignal) -> i32 {
    on_started.started();
    std::future::pending().await
}

#[export]
pub trait StartSignal {
    fn started(&self);
}

#[export]
pub fn transform(value: i32, callback: impl Fn(i32) -> i32) -> i32 {
    callback(value)
}

#[export]
pub trait Calculator {
    fn calculate(&self, value: i32) -> Result<i32, Failure>;
}

#[export]
pub fn call_calculator(calculator: impl Calculator, value: i32) -> Result<i32, Failure> {
    calculator.calculate(value)
}

#[export]
#[allow(async_fn_in_trait)]
pub trait AsyncCalculator {
    async fn calculate(&self, value: i32) -> i32;
}

#[export]
pub async fn call_async_calculator(calculator: impl AsyncCalculator, value: i32) -> i32 {
    calculator.calculate(value).await
}

pub struct Counter {
    value: std::sync::atomic::AtomicI32,
}

#[export]
impl Counter {
    pub fn new(value: i32) -> Self {
        Self {
            value: value.into(),
        }
    }
    pub fn from_value(value: i32) -> Self {
        Self::new(value)
    }
    pub fn increment(&self) -> i32 {
        self.value
            .fetch_add(1, std::sync::atomic::Ordering::Relaxed)
            + 1
    }
}

pub struct EventBus {
    values: StreamProducer<i32>,
    messages: StreamProducer<Message>,
}

#[export]
impl EventBus {
    pub fn new() -> Self {
        Self {
            values: StreamProducer::new(64),
            messages: StreamProducer::new(64),
        }
    }
    pub fn emit(&self, value: i32) {
        self.values.push(value);
    }
    pub fn emit_message(&self, value: Message) {
        self.messages.push(value);
    }
    #[ffi_stream(item = i32)]
    pub fn subscribe(&self) -> Arc<EventSubscription<i32>> {
        self.values.subscribe()
    }
    #[ffi_stream(item = i32, mode = "batch")]
    pub fn batches(&self) -> Arc<EventSubscription<i32>> {
        self.values.subscribe()
    }
    #[ffi_stream(item = i32, mode = "callback")]
    pub fn notifications(&self) -> Arc<EventSubscription<i32>> {
        self.values.subscribe()
    }
    #[ffi_stream(item = Message)]
    pub fn subscribe_messages(&self) -> Arc<EventSubscription<Message>> {
        self.messages.subscribe()
    }
}
