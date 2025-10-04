use anyhow::{Context, Result};
use std::process::Command;

/// Type out transcribed text using wtype and show notification
pub fn type_text(text: &str, wtype_path: &str, backend_name: &str) -> Result<()> {
    if text.trim().is_empty() {
        Command::new("notify-send")
            .args(&[
                "Voice Input",
                &format!("⚠️ No speech detected\nBackend: {}", backend_name),
                "-t", "2000",
                "-h", "string:x-canonical-private-synchronous:voice"
            ])
            .spawn()?;
        return Ok(());
    }

    // Small delay before typing
    std::thread::sleep(std::time::Duration::from_millis(30));
    
    // Type the text
    Command::new(wtype_path)
        .arg(text.trim())
        .spawn()
        .context("Failed to run wtype")?
        .wait()?;
    
    // Show success notification
    Command::new("notify-send")
        .args(&[
            "Voice Input",
            &format!("✅ Transcribed\nBackend: {}", backend_name),
            "-t", "1000",
            "-h", "string:x-canonical-private-synchronous:voice"
        ])
        .spawn()?;

    Ok(())
}