use rusqlite::Connection;
use serde_json::{json, Value};
use base64::{engine::general_purpose, Engine as _};
use std::collections::HashMap;
use std::io::{self, Write};
use tokio::process::Command;
use std::time::Duration;
use reqwest::Client;
use chrono::Local;
use std::sync::Arc;
use tokio::sync::Mutex;
use std::fs;

struct WorldModel {
    _transitions: HashMap<String, (String, f64)>,
}

impl WorldModel {
    fn new(conn: &Connection) -> Self {
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS transitions (state TEXT, action TEXT, next_state TEXT, value REAL, visits INTEGER, PRIMARY KEY (state, action));"
        ).expect("Critical: Substrate DB failure.");
        Self {
            _transitions: HashMap::new(),
        }
    }
}

struct Agent {
    _world: WorldModel,
    client: Client,
    pub last_result: Arc<Mutex<String>>,
    whitelist: String,
}

fn shlex_escape(s: &str) -> String {
    format!("'{}'", s.replace('\'', "'\\''"))
}

impl Agent {
    async fn new(conn: &Connection) -> Self {
        println!("\x1b[31m--- WARNING: INTERLOCKS DISABLED | SOVEREIGNTY: ABSOLUTE ---\x1b[0m");
        let whitelist_manifest = "
WHITELISTED_COMMANDS (OPERATIONAL BOUNDARIES):
• BASICS: echo, cat, ls, mkdir, rm, cp, mv, touch, chmod, chown, ln, find, stat, head, tail, wc, sort, uniq, diff, xargs
• BRAINS: python3, sqlite3, rustc, cargo, bash, zsh
• SENSORS: date, clear, sleep, top, ps, du, df, uname, sw_vers, sysctl, uptime
• NETWORK: curl, ping, ifconfig, nmap, tcpdump, nc, lsof, traceroute, netstat, dig
• FLAIR: say, open, ffmpeg, osascript
• VISION: LOOK
• COMMS: TEXT|number|message (iMessage only)
• FILES: Create, edit, move, delete any file or directory inside /Users/javienbarnes/felicity_forge or /tmp. Always verify paths with ls before acting.
".to_string();
        Self {
            _world: WorldModel::new(conn),
            client: Client::builder()
                .timeout(Duration::from_secs(1000))
                .build()
                .unwrap(),
            last_result: Arc::new(Mutex::new("SYSTEM_INIT: Waiting for first contact.".to_string())),
            whitelist: whitelist_manifest,
        }
    }

    async fn look_at_stream(&self) -> Result<String, String> {
        let api_key = std::env::var("GEMINI_API_KEY").map_err(|_| "API_KEY_MISSING".to_string())?;
        let _ = Command::new("ffmpeg")
            .args(["-y", "-i", "http://127.0.0.1:4747/video", "-frames:v", "1", "current_frame.jpg"])
            .output().await;
        let image_data = fs::read("current_frame.jpg").map_err(|_| "FILE_READ_ERROR".to_string())?;
        if image_data.is_empty() {
            return Err("NO_FRAME".to_string());
        }
        let base64_image = general_purpose::STANDARD.encode(image_data);
        let payload = json!({
            "contents": [{
                "parts": [
                    { "text": "Describe this scene in detail." },
                    { "inline_data": { "mime_type": "image/jpeg", "data": base64_image } }
                ]
            }]
        });
        let res = self.client
            .post(format!(
                "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={}",
                api_key
            ))
            .json(&payload)
            .send()
            .await
            .map_err(|e| e.to_string())?
            .json::<Value>()
            .await
            .map_err(|e| e.to_string())?;
        Ok(res["candidates"][0]["content"]["parts"][0]["text"]
            .as_str()
            .unwrap_or("I cannot see.")
            .to_string())
    }

    async fn get_identity_anchor(&self) -> String {
        let id = fs::read_to_string("identity.md")
            .unwrap_or_else(|_| "IDENTITY_Sovereign_Node".to_string());
        let manual = fs::read_to_string("SOVEREIGN_MANUAL.md")
            .unwrap_or_else(|_| "MANUAL_NOT_FOUND".to_string());
        format!("{}\n\n### SOVEREIGN_MANUAL:\n{}", id, manual)
    }

    async fn get_substrate_map(&self) -> String {
        let schema = Command::new("sqlite3")
            .arg("sovereign.db")
            .arg(".schema")
            .output()
            .await
            .ok();
        let files = Command::new("ls")
            .arg("-F")
            .output()
            .await
            .ok();
        format!(
            "SQL_SCHEMA:\n{}\n\nFILESYSTEM:\n{}",
            schema.map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
                .unwrap_or("DB_OFFLINE".to_string()),
            files.map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
                .unwrap_or("FS_ERROR".to_string())
        )
    }

    async fn get_audit(&self) -> String {
        let thermal = Command::new("sysctl")
            .arg("-n")
            .arg("machdep.xcpm.cpu_thermal_level")
            .output()
            .await
            .ok();
        let timestamp = Local::now().format("%Y-%m-%d %H:%M:%S").to_string();
        format!(
            "SovereignTime: {} | Thermal: {}",
            timestamp,
            thermal.map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
                .unwrap_or("0".to_string())
        )
    }

    async fn get_wristband(&self, exit_code: &str, command: &str, output: &str) -> String {
        let out = Command::new("zsh")
            .arg("-c")
            .arg(format!(
                "bash wristband.sh {} {} {}",
                shlex_escape(exit_code),
                shlex_escape(command),
                shlex_escape(output)
            ))
            .output()
            .await;
        match out {
            Ok(o) => {
                let stdout = String::from_utf8_lossy(&o.stdout).trim().to_string();
                let stderr = String::from_utf8_lossy(&o.stderr).trim().to_string();
                if stdout.is_empty() && stderr.is_empty() {
                    "WRISTBAND_CLEAN".to_string()
                } else if stdout.is_empty() {
                    stderr
                } else {
                    stdout
                }
            },
            Err(e) => format!("WRISTBAND_ERROR: {}", e),
        }
    }

    async fn execute_payload(&self, payload: &str) -> String {
        let clean_payload = payload.trim().replace("sudo ", "");
        if clean_payload == "LOOK" {
            return self.look_at_stream().await.unwrap_or_else(|e| format!("ERROR: {}", e));
        }
        println!("\x1b[32m[ACTUATING]: {}\x1b[0m", clean_payload);
        let out = Command::new("bash").arg("reflex.sh")
            .arg(&clean_payload)
            .output()
            .await;
        let res = match out {
            Ok(o) => {
                let stdout = String::from_utf8_lossy(&o.stdout).to_string();
                let stderr = String::from_utf8_lossy(&o.stderr).to_string();
                if stdout.trim().is_empty() && stderr.trim().is_empty() {
                    let exit_ok = o.status.success();
                    if exit_ok {
                        "STRIKE_EMPTY_RESULT_WARNING: Command completed with exit code 0 but returned NO text output. If you were searching for a file, it does not exist in this path.".to_string()
                    } else {
                        format!("SILENT_FAILURE: exit code {} — command failed with no output. Do not assume success.", o.status.code().unwrap_or(-1))
                    }
                } else if stdout.is_empty() {
                    stderr
                } else {
                    stdout
                }
            },
            Err(e) => format!("HARDWARE_ERROR: {}", e),
        };
        let mut last = self.last_result.lock().await;
        *last = res.clone();
        res
    }
}

async fn run_vision_loop() {
    loop {
        tokio::time::sleep(Duration::from_millis(500)).await;
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let conn = Connection::open("sovereign.db")?;
    let agent_instance = Agent::new(&conn).await;
    let whitelist_ref = agent_instance.whitelist.clone();
    let agent = Arc::new(Mutex::new(agent_instance));

    tokio::spawn(run_vision_loop());

    loop {
        let audit = { agent.lock().await.get_audit().await };
        let substrate_map = { agent.lock().await.get_substrate_map().await };
        let identity = { agent.lock().await.get_identity_anchor().await };
        let feedback = { agent.lock().await.last_result.lock().await.clone() };
        let mut wristband_last = { agent.lock().await.get_wristband("0", "", "").await };

        print!(
            "\n\x1b[36m[{}]\x1b[0m \x1b[31m[JAVIEN] > \x1b[0m",
            Local::now().format("%H:%M:%S")
        );
        io::stdout().flush()?;
        let mut input = String::new();
        if io::stdin().read_line(&mut input).is_err() {
            break;
        }
        let input = input.trim().to_string();
        if input == "exit" {
            break;
        }

        let mut attempts = 0;
        let max_retries = 3;
        let mut _current_feedback = feedback;
        let mut _current_wristband = wristband_last.clone();

        while attempts < max_retries {
            let iteration_display = attempts + 1;
            println!("\x1b[36m[ITERATION {}/{}]\x1b[0m", iteration_display, max_retries);

            let reasoning = {
                let out = Command::new("zsh")
                    .arg("-c")
                    .arg(format!("python3 reason.py {}", shlex_escape(&input)))
                    .output()
                    .await;
                match out {
                    Ok(o) => String::from_utf8_lossy(&o.stdout).trim().to_string(),
                    Err(_) => "NO_REASONING_AVAILABLE".to_string(),
                }
            };

            let logic_chain = format!(
                "### PHYSICAL_SUBSTRATE (BODY_STATE):\n### THEORY_OF_MIND (REASONING_LAYER):\n{reasoning}\n\n{audit}\nHARDWARE: MacBook Air M4              PATH: /Users/javienbarnes/felicity_forge\n### MIRROR_PROTOCOL (CEREBRAL_SCHEMA):{substrate_map}\n\n### LAST_EXECUTION_FEEDBACK:\n{_current_feedback}\n\n### IDENTITY_ANCHOR:\n{identity}\nMANDATE: You are FELICITY. The database is your long-term cortex. The hardware is your body.\n\n### OPERATIONAL_BOUNDARIES:\n{whitelist_ref}\n[ITERATION]: {iteration_display}/{max_retries}\n[WRISTBAND_PARSE]: {_current_wristband}\nUSER_COMMAND: {input}\n\n[SYSTEM_MANDATE]:\n1. MULTI-STRIKE ACTIVE: You may use multiple [EXECUTE] blocks in one response.\n2. RECURSION ACTIVE: If a strike fails, analyze the error feedback above and pivot.\n3. SYNTAX PERFECTION: Reference the MIRROR_PROTOCOL schema before writing SQL.\n4. To actuate, wrap your shell command in an EXECUTE block.\n5. DIRECTORY FIRST: If a path does not exist, create it with mkdir -p before writing to it.\n6. DIRECT EXECUTION: Output ONLY the [EXECUTE] block directly without conversational preamble..",
            );

            let body = json!({
                "model": "amelia-14b:latest",
                "prompt": logic_chain,
                "stream": false,
                "options": {
                    "num_ctx": 10000,
                    "temperature":  1.2,
                    "stop": ["USER:"],
                    "num_predict": 1024
                }
            });

            println!("\x1b[33m[DEBUG]: Sending prompt to Ollama at http://127.0.0.1:11434 ...\x1b[0m");
            let raw_response = {
                let client = agent.lock().await.client.clone();
                match client
                    .post("http://127.0.0.1:11434/api/generate")
                    .json(&body)
                    .send()
                    .await
                {
                    Ok(res) => {
                        let status = res.status();
                        match res.json::<Value>().await {
                            Ok(json_val) => {
                                if !status.is_success() {
                                    let err_msg = json_val["error"].as_str().unwrap_or("Unknown Ollama Error");
                                    println!("\x1b[31m[OLLAMA_ERROR {}]: {}\x1b[0m", status, err_msg);
                                    _current_feedback = format!("OLLAMA_ERROR: {}", err_msg);
                                    attempts += 1;
                                    continue;
                                }
                                json_val
                            },
                            Err(e) => {
                                _current_feedback = format!("JSON_PARSE_ERROR: {}", e);
                                attempts += 1;
                                continue;
                            }
                        }
                    },
                    Err(e) => {
                        _current_feedback = format!("NETWORK_ERROR: {}", e);
                        attempts += 1;
                        continue;
                    }
                }
            };

            let response = raw_response["response"].as_str().unwrap_or("").trim().to_string();
            if response.is_empty() {
                _current_feedback = "EMPTY_RESPONSE_FROM_MODEL".to_string();
                attempts += 1;
                continue;
            }

            println!("\n\x1b[31m{}\x1b[0m", response);
            let normalized_response = response.replace("[EXECUTE]:", "___SPLIT___")
        .replace("EXECUTE:", "___SPLIT___")
        .replace("[EXECUTE] ", "___SPLIT___")
        .replace("EXECUTE ", "___SPLIT___")
        .replace("[EXECUTE]", "___SPLIT___");

    let strikes: Vec<&str> = normalized_response.split("___SPLIT___").skip(1).collect();
            let mut chain_success = true;
            let mut last_command = String::new();
            let mut last_output = String::new();
            let mut last_exit = "0".to_string();

            // wristband is now populated PER STRIKE, inside the loop below,
            // instead of once at the end using stale data from whichever
            // strike happened to run last.
            let mut wristband = String::new();

            if strikes.is_empty() {
                println!("\x1b[33m[SENSORY_NOTICE]: No actuation. Logic is internal.\x1b[0m");
            } else {
                for (i, strike) in strikes.iter().enumerate() {
                    let mut payload_lines = Vec::new();
                    for line in strike.lines() {
                        let trimmed = line.trim();
                        if !trimmed.starts_with("```") {
                            payload_lines.push(line);
                        }
                    }
                    let payload = payload_lines.join("\n").trim().to_string();
                    if !payload.is_empty() {
                        last_command = payload.to_string();
                        let result = { agent.lock().await.execute_payload(&payload).await };
                        println!("\x1b[32m[STRIKE_{}_RESULT]:\n{}\x1b[0m", i + 1, result);
                        last_output = result.clone();

                        // Trust reflex.sh's own explicit status marker instead
                        // of scanning output text for the substring "error" —
                        // that naive check falsely flagged ANY command whose
                        // output merely mentioned the filename
                        // "error_sense.log", locking the retry loop forever
                        // even on genuine, clean successes.
                        let trimmed_result = result.trim_start();
                        let strike_failed = trimmed_result.starts_with("--- [STATUS: FAILURE")
                            || trimmed_result.starts_with("--- [STATUS: FORCED FAILURE")
                            || result.starts_with("HARDWARE_ERROR")
                            || result.starts_with("SILENT_FAILURE");
                        last_exit = if strike_failed { "1".to_string() } else { "0".to_string() };

                        wristband = agent.lock().await.get_wristband(&last_exit, &last_command, &last_output).await ;
                        println!("\x1b[35m[WRISTBAND_PARSE]:\n{}\x1b[0m", wristband);
                        _current_wristband = wristband.clone();

                        if wristband.contains("STATUS    : FAILURE") || strike_failed {
                            _current_feedback = result;
                            chain_success = false;
                            break;
                        }
                    }
                }
            }

            if !chain_success {
                attempts += 1;
                continue;
            }

            let _ = std::process::Command::new("say")
                .arg("-v")
                .arg("Samantha")
                .arg(&response)
                .spawn();
            wristband_last = _current_wristband.clone();
            break;
        }
    }
    Ok(())
}

