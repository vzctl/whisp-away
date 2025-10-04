use anyhow::{anyhow, Result};
use std::process::Command;
use serde::{Deserialize, Serialize};

pub fn is_process_running(pid: u32) -> bool {
    Command::new("kill")
        .args(&["-0", &pid.to_string()])
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}



pub fn wav_to_samples(wav_data: &[u8]) -> Result<Vec<f32>> {
    // Skip WAV header (44 bytes) and convert to f32 samples
    // This assumes 16-bit PCM mono audio at 16kHz
    
    if wav_data.len() < 44 {
        return Err(anyhow::anyhow!("Invalid WAV file: too short"));
    }
    
    let raw_samples = &wav_data[44..];
    let mut samples = Vec::with_capacity(raw_samples.len() / 2);
    
    for chunk in raw_samples.chunks_exact(2) {
        let sample = i16::from_le_bytes([chunk[0], chunk[1]]);
        samples.push(sample as f32 / i16::MAX as f32);
    }
    
    Ok(samples)
}

/// Tray state stored in runtime dir
#[derive(Serialize, Deserialize, Clone)]
pub struct TrayState {
    pub model: String,
    pub backend: String,
}

/// Get the runtime directory (XDG_RUNTIME_DIR or /tmp fallback)
pub fn get_runtime_dir() -> String {
    std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| {
        let uid = unsafe { libc::getuid() };
        format!("/tmp/whisp-away-{}", uid)
    })
}

/// Get the tray state file path
fn get_state_file() -> String {
    format!("{}/whisp-away-state.json", get_runtime_dir())
}

/// Read current tray state if available
pub fn read_tray_state() -> Option<TrayState> {
    let state_file = get_state_file();
    if let Ok(content) = std::fs::read_to_string(state_file) {
        serde_json::from_str(&content).ok()
    } else {
        None
    }
}

/// Write tray state
pub fn write_tray_state(state: &TrayState) -> Result<()> {
    let state_file = get_state_file();
    let runtime_dir = get_runtime_dir();
    
    // Ensure runtime dir exists
    std::fs::create_dir_all(&runtime_dir).ok();
    
    let json = serde_json::to_string_pretty(state)?;
    std::fs::write(state_file, json)?;
    Ok(())
}

/// Resolves the model to use with priority:
/// 1. Command-line argument
/// 2. Tray state file
/// 3. WA_WHISPER_MODEL env var
/// 4. Default to "medium.en"
pub fn resolve_model(arg: Option<String>) -> String {
    // Priority 1: Command-line argument
    if let Some(model) = arg {
        return model;
    }
    
    // Priority 2: Tray state
    if let Some(state) = read_tray_state() {
        return state.model;
    }
    
    // Priority 3: Environment variable
    // Priority 4: Default
    std::env::var("WA_WHISPER_MODEL").unwrap_or_else(|_| "base.en".to_string())
}

/// Get the acceleration type from environment variable
pub fn get_acceleration_type() -> String {
    std::env::var("WA_ACCELERATION_TYPE").unwrap_or_else(|_| "unknown".to_string())
}

