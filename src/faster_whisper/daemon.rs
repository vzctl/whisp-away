use anyhow::{Context, Result};
use std::process::Command;

pub fn run_daemon(model: &str, socket_path: &str) -> Result<()> {
    // Get Python interpreter and script paths from environment
    let python_path = std::env::var("FASTER_WHISPER_PYTHON")
        .context("FASTER_WHISPER_PYTHON not set")?;
    let pythonpath = std::env::var("FASTER_WHISPER_PYTHONPATH")
        .context("FASTER_WHISPER_PYTHONPATH not set")?;
    let script_path = std::env::var("FASTER_WHISPER_DAEMON_SCRIPT")
        .context("FASTER_WHISPER_DAEMON_SCRIPT not set")?;
    
    // Check if script exists
    if !std::path::Path::new(&script_path).exists() {
        return Err(anyhow::anyhow!("whisper_daemon.py not found at {}", script_path));
    }
    
    // Run Python with injected environment
    let status = Command::new(&python_path)
        .arg(&script_path)
        .env("PYTHONPATH", &pythonpath)
        .env("WA_WHISPER_MODEL", model)
        .env("WA_WHISPER_SOCKET", socket_path)
        // Pass through CUDA environment if present
        .env("CUDA_VISIBLE_DEVICES", std::env::var("CUDA_VISIBLE_DEVICES").unwrap_or_default())
        .env("LD_LIBRARY_PATH", std::env::var("LD_LIBRARY_PATH").unwrap_or_default())
        .status()
        .context("Failed to run faster-whisper daemon")?;
    
    if !status.success() {
        return Err(anyhow::anyhow!("Faster-whisper daemon exited with error"));
    }
    
    Ok(())
}