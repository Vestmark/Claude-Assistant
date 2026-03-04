#!/usr/bin/env python3
"""
Claude Code Assistant - GUI Application (Linux/Ubuntu)

Installs and configures Claude Code with AWS Bedrock support.
- Checks prerequisite tools (Git, AWS CLI, Claude Code)
- Installs Claude Code via official installer (claude.ai)
- Configures environment variables via ~/.claude-code-env
- Provides model selection dropdowns for Bedrock

Version: 7.1.0
GitHub: https://github.com/Vestmark/Claude-Assistant
"""

import os
import re
import shutil
import subprocess
import sys
import threading
import tkinter as tk
import urllib.request
from datetime import datetime
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

# ============================================================
# Script Version & Update Configuration
# ============================================================
SCRIPT_VERSION = "7.0.0"
GITHUB_RAW_URL = "https://raw.githubusercontent.com/Vestmark/Claude-Assistant/main/Claude_Code_Assistant_Linux.py"
SCRIPT_PATH = os.path.abspath(__file__)

ENV_FILE = Path.home() / ".claude-code-env"
BASHRC = Path.home() / ".bashrc"
AWS_CONFIG = Path.home() / ".aws" / "config"

MANAGED_VARS = [
    "CLAUDE_CODE_USE_BEDROCK",
    "AWS_REGION",
    "AWS_PROFILE",
    "ANTHROPIC_MODEL",
    "ANTHROPIC_SMALL_FAST_MODEL",
    "CLAUDE_CODE_DEFAULT_PROJECT",
]

REGIONS = [
    "us-east-1",
    "us-east-2",
    "us-west-2",
    "eu-west-1",
    "eu-west-2",
    "eu-central-1",
    "ap-northeast-1",
    "ap-southeast-1",
    "ap-southeast-2",
]

SSO_REGIONS = [
    "us-east-1",
    "us-east-2",
    "us-west-2",
    "eu-west-1",
    "eu-west-2",
    "eu-central-1",
]

PRIMARY_MODELS = [
    ("Claude Sonnet 4.6", "us.anthropic.claude-sonnet-4-6"),
    ("Claude Sonnet 4.5", "us.anthropic.claude-sonnet-4-5-20250929-v1:0"),
    ("Claude Sonnet 4", "us.anthropic.claude-sonnet-4-20250514-v1:0"),
    ("Claude Haiku 4.5", "us.anthropic.claude-haiku-4-5-20251001-v1:0"),
]

SMALL_MODELS = [
    ("Claude Haiku 3.5", "us.anthropic.claude-3-5-haiku-20241022-v1:0"),
    ("Claude Haiku 3", "us.anthropic.claude-3-haiku-20240307-v1:0"),
    ("Claude Sonnet 4", "us.anthropic.claude-sonnet-4-20250514-v1:0"),
]

# -- Colors matching the original WPF theme --
BG = "#f3f4f6"
CARD_BG = "#ffffff"
CARD_BORDER = "#e5e7eb"
TEXT_PRIMARY = "#1e293b"
TEXT_SECONDARY = "#374151"
TEXT_MUTED = "#6b7280"
TEXT_FAINT = "#9ca3af"
GREEN = "#059669"
RED = "#dc2626"
PRIMARY_BTN_BG = "#4f46e5"
PRIMARY_BTN_HOVER = "#4338ca"
PRIMARY_BTN_DISABLED = "#c7d2fe"
SECONDARY_BTN_BG = "#e5e7eb"
SECONDARY_BTN_HOVER = "#d1d5db"
DANGER_BTN_BG = "#ef4444"
DANGER_BTN_HOVER = "#dc2626"
LOG_BG = "#f8fafc"
LOG_FG = "#334155"
STATUS_BAR_BG = "#e5e7eb"


def find_terminal_emulator():
    """Return a terminal emulator command list that works on this system."""
    for term in ["gnome-terminal", "konsole", "xfce4-terminal", "mate-terminal"]:
        if shutil.which(term):
            return term
    if shutil.which("x-terminal-emulator"):
        return "x-terminal-emulator"
    if shutil.which("xterm"):
        return "xterm"
    return None


def get_tool_info(command, version_args=None):
    """Check if a command-line tool is available and return its version string."""
    if version_args is None:
        version_args = ["--version"]
    exe = shutil.which(command)
    if not exe:
        return None
    try:
        result = subprocess.run(
            [exe] + version_args,
            capture_output=True,
            text=True,
            timeout=10,
        )
        output = (result.stdout or result.stderr or "").strip()
        first_line = output.split("\n")[0].strip()
        return first_line if first_line else "(found but version unknown)"
    except Exception:
        return "(found but version unknown)"


def read_env_file():
    """Read key=value pairs from the managed env file."""
    values = {}
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            m = re.match(r'^export\s+([A-Za-z_][A-Za-z_0-9]*)=["\']?(.*?)["\']?\s*$', line)
            if m:
                values[m.group(1)] = m.group(2)
    return values


def write_env_file(env_dict):
    """Persist environment variables to the managed env file."""
    lines = []
    for k, v in env_dict.items():
        lines.append(f'export {k}="{v}"')
    ENV_FILE.write_text("\n".join(lines) + "\n")
    ensure_env_sourced()
    for k, v in env_dict.items():
        os.environ[k] = v


def ensure_env_sourced():
    """Make sure ~/.bashrc sources our env file."""
    source_line = f'[ -f "{ENV_FILE}" ] && source "{ENV_FILE}"'
    if BASHRC.exists():
        content = BASHRC.read_text()
        if str(ENV_FILE) in content:
            return
    else:
        content = ""
    with open(BASHRC, "a") as f:
        f.write(f"\n# Claude Code environment variables\n{source_line}\n")


def get_env_var(name):
    """Read a variable from the env file, falling back to the current environment."""
    stored = read_env_file()
    if name in stored:
        return stored[name]
    return os.environ.get(name)


def get_latest_script_version():
    """Download the script from GitHub and extract version number."""
    try:
        with urllib.request.urlopen(GITHUB_RAW_URL, timeout=10) as response:
            content = response.read().decode('utf-8')
            match = re.search(r'SCRIPT_VERSION\s*=\s*"([^"]+)"', content)
            if match:
                return match.group(1)
            return "NO_VERSION_FOUND"
    except Exception:
        return None


def compare_versions(v1, v2):
    """Compare two semantic version strings. Returns -1 if v1 < v2, 0 if equal, 1 if v1 > v2."""
    v1_parts = [int(x) for x in v1.split('.')]
    v2_parts = [int(x) for x in v2.split('.')]
    max_len = max(len(v1_parts), len(v2_parts))

    v1_parts.extend([0] * (max_len - len(v1_parts)))
    v2_parts.extend([0] * (max_len - len(v2_parts)))

    for p1, p2 in zip(v1_parts, v2_parts):
        if p1 < p2:
            return -1
        if p1 > p2:
            return 1
    return 0


def update_script(new_version, log_callback=None):
    """Download and install the new version of the script."""
    try:
        if log_callback:
            log_callback(f"Downloading version {new_version} from GitHub...", "INFO")

        with urllib.request.urlopen(GITHUB_RAW_URL, timeout=30) as response:
            new_content = response.read().decode('utf-8')

        if log_callback:
            log_callback("Installing new version...", "INFO")

        with open(SCRIPT_PATH, 'w', encoding='utf-8') as f:
            f.write(new_content)

        if log_callback:
            log_callback(f"Update complete! Restart the application to use version {new_version}.", "OK")

        return True
    except Exception as e:
        if log_callback:
            log_callback(f"Update failed: {e}", "ERROR")
        return False


class HoverButton(tk.Button):
    """Button with hover color change."""

    def __init__(self, master, bg_normal, bg_hover, fg="white", **kwargs):
        super().__init__(master, bg=bg_normal, fg=fg, activebackground=bg_hover,
                         activeforeground=fg, relief="flat", cursor="hand2",
                         font=("sans-serif", 10, "bold"), padx=16, pady=6, **kwargs)
        self._bg_normal = bg_normal
        self._bg_hover = bg_hover
        self.bind("<Enter>", lambda e: self.configure(bg=self._bg_hover))
        self.bind("<Leave>", lambda e: self.configure(bg=self._bg_normal))


class ClaudeCodeAssistant:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("Claude Code Assistant")
        self.root.geometry("982x750")
        self.root.configure(bg=BG)
        self.root.minsize(700, 550)

        self.git_installed = False
        self.aws_installed = False
        self.claude_installed = False

        self._build_styles()
        self._build_header()
        self._build_notebook()
        self._build_install_tab()
        self._build_configure_tab()
        self._build_sso_tab()
        self._build_persistent_buttons()
        self._build_status_bar()

        self.root.after(200, self._on_start)

    # ------------------------------------------------------------------ styles
    def _build_styles(self):
        style = ttk.Style()
        style.theme_use("clam")
        style.configure("TNotebook", background=BG, borderwidth=0)
        style.configure("TNotebook.Tab", font=("sans-serif", 11, "bold"),
                         padding=[14, 6], background=SECONDARY_BTN_BG,
                         foreground=TEXT_SECONDARY)
        style.map("TNotebook.Tab",
                  background=[("selected", CARD_BG)],
                  foreground=[("selected", TEXT_PRIMARY)])
        style.configure("TFrame", background=BG)
        style.configure("Card.TFrame", background=CARD_BG)
        style.configure("TLabel", background=BG, foreground=TEXT_SECONDARY,
                         font=("sans-serif", 10))
        style.configure("Card.TLabel", background=CARD_BG,
                         foreground=TEXT_SECONDARY, font=("sans-serif", 10))
        style.configure("Header.TLabel", font=("sans-serif", 16, "bold"),
                         foreground=TEXT_PRIMARY, background=BG)
        style.configure("SubHeader.TLabel", foreground=TEXT_MUTED,
                         background=BG, font=("sans-serif", 10))
        style.configure("Section.TLabel", font=("sans-serif", 13, "bold"),
                         foreground=TEXT_PRIMARY, background=CARD_BG)
        style.configure("Muted.TLabel", foreground=TEXT_MUTED,
                         background=CARD_BG, font=("sans-serif", 10))
        style.configure("Faint.TLabel", foreground=TEXT_FAINT,
                         background=BG, font=("sans-serif", 9))
        style.configure("FormLabel.TLabel", foreground=TEXT_SECONDARY,
                         background=CARD_BG, font=("sans-serif", 10, "bold"))
        style.configure("Green.TLabel", foreground=GREEN, background=CARD_BG,
                         font=("sans-serif", 10))
        style.configure("Red.TLabel", foreground=RED, background=CARD_BG,
                         font=("sans-serif", 10))
        style.configure("TCheckbutton", background=CARD_BG,
                         foreground=TEXT_SECONDARY, font=("sans-serif", 10, "bold"))
        style.configure("TCombobox", font=("sans-serif", 10))

    # ------------------------------------------------------------------ header
    def _build_header(self):
        frame = tk.Frame(self.root, bg=BG)
        frame.pack(fill="x", padx=20, pady=(16, 0))

        # Left side - title and subtitle
        left_frame = tk.Frame(frame, bg=BG)
        left_frame.pack(side="left", fill="both", expand=True)
        ttk.Label(left_frame, text="Claude Code Assistant",
                  style="Header.TLabel").pack(anchor="w")
        ttk.Label(left_frame, text="Designed by Vestmark IT",
                  style="SubHeader.TLabel").pack(anchor="w", pady=(2, 0))

        # Right side - version info and update button
        right_frame = tk.Frame(frame, bg=BG)
        right_frame.pack(side="right")
        self.version_label = tk.Label(right_frame, text=f"v{SCRIPT_VERSION}",
                                      bg=BG, fg=TEXT_FAINT,
                                      font=("sans-serif", 9))
        self.version_label.pack(anchor="e")
        self.btn_check_update = HoverButton(
            right_frame, SECONDARY_BTN_BG, SECONDARY_BTN_HOVER,
            fg=TEXT_SECONDARY, text="Check for Updates",
            command=self._on_check_update)
        self.btn_check_update.config(font=("sans-serif", 9, "bold"), padx=10, pady=4)
        self.btn_check_update.pack(anchor="e", pady=(4, 0))

    # ------------------------------------------------------------------ notebook
    def _build_notebook(self):
        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(fill="both", expand=True, padx=20, pady=(12, 0))

    # ------------------------------------------------------------------ persistent buttons
    def _build_persistent_buttons(self):
        btn_frame = tk.Frame(self.root, bg=BG, padx=20)
        btn_frame.pack(fill="x", pady=(8, 0))

        right_frame = tk.Frame(btn_frame, bg=BG)
        right_frame.pack(side="right")

        self.btn_start_claude = HoverButton(
            right_frame, PRIMARY_BTN_BG, PRIMARY_BTN_HOVER,
            text="Start Claude", command=self._on_start_claude)
        self.btn_start_claude.pack(side="left", padx=(0, 6))

        self.btn_sso_login = HoverButton(
            right_frame, SECONDARY_BTN_BG, SECONDARY_BTN_HOVER, fg=TEXT_SECONDARY,
            text="SSO Login (Refresh Token)", command=self._on_sso_login)
        self.btn_sso_login.pack(side="left")

    # ------------------------------------------------------------------ status bar
    def _build_status_bar(self):
        bar = tk.Frame(self.root, bg=STATUS_BAR_BG, padx=12, pady=6)
        bar.pack(fill="x", padx=20, pady=(10, 14))
        self.status_label = tk.Label(bar, text="Ready", bg=STATUS_BAR_BG,
                                     fg="#4b5563", font=("sans-serif", 10),
                                     anchor="w")
        self.status_label.pack(fill="x")

    def set_status(self, text):
        self.status_label.config(text=text)

    # ================================================================== INSTALL TAB
    def _build_install_tab(self):
        outer = ttk.Frame(self.notebook)
        self.notebook.add(outer, text="   Install   ")

        canvas = tk.Canvas(outer, bg=BG, highlightthickness=0)
        scrollbar = ttk.Scrollbar(outer, orient="vertical", command=canvas.yview)
        scroll_frame = ttk.Frame(canvas)
        scroll_frame.bind("<Configure>",
                          lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=scroll_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")
        canvas.bind_all("<MouseWheel>",
                        lambda e: canvas.yview_scroll(int(-1 * (e.delta / 120)), "units"))
        scroll_frame.bind("<Configure>",
                          lambda e: canvas.itemconfig(
                              canvas.find_withtag("all")[0], width=e.width)
                          if canvas.find_withtag("all") else None)

        # -- Prerequisite card --
        card = self._card(scroll_frame)
        ttk.Label(card, text="Prerequisite Status",
                  style="Section.TLabel").pack(anchor="w")
        ttk.Label(card, text="Tools required by Claude Code. Click Refresh to re-check.",
                  style="Muted.TLabel").pack(anchor="w", pady=(0, 10))

        self.prereq_rows = {}
        for tool in ("Git", "AWS CLI", "Claude Code"):
            row = tk.Frame(card, bg=CARD_BG)
            row.pack(fill="x", pady=2)
            dot = tk.Label(row, text="\u25CF", fg=TEXT_FAINT, bg=CARD_BG,
                           font=("sans-serif", 12), width=2)
            dot.pack(side="left")
            tk.Label(row, text=tool, fg=TEXT_SECONDARY, bg=CARD_BG,
                     font=("sans-serif", 10, "bold"), width=12,
                     anchor="w").pack(side="left", padx=(4, 8))
            status = tk.Label(row, text="Checking...", fg=TEXT_MUTED, bg=CARD_BG,
                              font=("sans-serif", 10), anchor="w")
            status.pack(side="left", fill="x", expand=True)
            self.prereq_rows[tool] = (dot, status)

        # -- Buttons row 1: prerequisite installs --
        btn_frame1 = tk.Frame(scroll_frame, bg=BG)
        btn_frame1.pack(fill="x", pady=(8, 0))

        self.btn_refresh = HoverButton(
            btn_frame1, SECONDARY_BTN_BG, SECONDARY_BTN_HOVER, fg=TEXT_SECONDARY,
            text="Refresh Status", command=self._on_refresh)
        self.btn_refresh.pack(side="left", padx=(0, 6))

        self.btn_install_git = HoverButton(
            btn_frame1, PRIMARY_BTN_BG, PRIMARY_BTN_HOVER,
            text="Install Git", command=self._on_install_git)
        self.btn_install_git.pack(side="left", padx=(0, 6))

        self.btn_install_aws = HoverButton(
            btn_frame1, PRIMARY_BTN_BG, PRIMARY_BTN_HOVER,
            text="Install AWS CLI", command=self._on_install_aws)
        self.btn_install_aws.pack(side="left")

        # -- Buttons row 2: Claude Code --
        btn_frame2 = tk.Frame(scroll_frame, bg=BG)
        btn_frame2.pack(fill="x", pady=(6, 0))

        self.btn_install = HoverButton(
            btn_frame2, PRIMARY_BTN_BG, PRIMARY_BTN_HOVER,
            text="Install Claude Code", command=self._on_install)
        self.btn_install.pack(side="left", padx=(0, 6))

        self.btn_uninstall = HoverButton(
            btn_frame2, DANGER_BTN_BG, DANGER_BTN_HOVER,
            text="Uninstall Claude Code", command=self._on_uninstall)
        self.btn_uninstall.pack(side="left")

        ttk.Label(
            scroll_frame,
            text=("Git and AWS CLI require elevated privileges (you will be prompted "
                  "for your password). Claude Code is installed at the user level "
                  "via the official installer and does not require elevation."),
            style="Faint.TLabel", wraplength=720,
        ).pack(anchor="w", pady=(6, 8))

        # -- Log card --
        log_card = self._card(scroll_frame)
        ttk.Label(log_card, text="Output Log",
                  style="Section.TLabel").pack(anchor="w", pady=(0, 6))
        self.install_log = tk.Text(
            log_card, height=8, wrap="word", font=("monospace", 9),
            bg=LOG_BG, fg=LOG_FG, relief="solid", bd=1,
            highlightthickness=0, padx=8, pady=6)
        self.install_log.pack(fill="both", expand=True)
        self.install_log.config(state="disabled")

    # ================================================================ CONFIGURE TAB
    def _build_configure_tab(self):
        outer = ttk.Frame(self.notebook)
        self.notebook.add(outer, text="   Configure Claude   ")

        canvas = tk.Canvas(outer, bg=BG, highlightthickness=0)
        scrollbar = ttk.Scrollbar(outer, orient="vertical", command=canvas.yview)
        scroll_frame = ttk.Frame(canvas)
        scroll_frame.bind("<Configure>",
                          lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=scroll_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")

        # -- Settings card --
        card = self._card(scroll_frame)
        ttk.Label(card, text="Environment Configuration",
                  style="Section.TLabel").pack(anchor="w")
        ttk.Label(card,
                  text="All variables are persisted to ~/.claude-code-env (sourced from ~/.bashrc).",
                  style="Muted.TLabel").pack(anchor="w", pady=(0, 12))

        form = tk.Frame(card, bg=CARD_BG)
        form.pack(fill="x")

        self.cmb_region = self._form_row_combo(form, 0, "AWS Region (AWS_REGION):", REGIONS, "us-east-1")
        self.txt_profile = self._form_row_entry(form, 1, "AWS Profile (AWS_PROFILE):", "claude-code")

        primary_labels = [m[0] for m in PRIMARY_MODELS]
        self.cmb_primary = self._form_row_combo(form, 2, "Primary Model (ANTHROPIC_MODEL):", primary_labels, primary_labels[1])

        small_labels = [m[0] for m in SMALL_MODELS]
        self.cmb_small = self._form_row_combo(form, 3, "Small/Fast Model:", small_labels, small_labels[1])

        self.txt_project_path = self._form_row_entry_with_browse(form, 4, "Default Project Location (optional):", "")

        self.bedrock_var = tk.BooleanVar(value=True)
        chk = ttk.Checkbutton(form, text="  Use AWS Bedrock  (CLAUDE_CODE_USE_BEDROCK = 1)",
                               variable=self.bedrock_var, style="TCheckbutton")
        chk.grid(row=5, column=0, columnspan=3, sticky="w", pady=(10, 0))

        # -- Buttons --
        btn_frame = tk.Frame(scroll_frame, bg=BG)
        btn_frame.pack(fill="x", pady=(8, 0))

        self.btn_apply = HoverButton(
            btn_frame, PRIMARY_BTN_BG, PRIMARY_BTN_HOVER,
            text="Apply Configuration", command=self._on_apply_config)
        self.btn_apply.pack(side="left", padx=(0, 6))

        self.btn_load = HoverButton(
            btn_frame, SECONDARY_BTN_BG, SECONDARY_BTN_HOVER, fg=TEXT_SECONDARY,
            text="Load Current Values", command=self._on_load_config)
        self.btn_load.pack(side="left")

        # -- Current config card --
        cfg_card = self._card(scroll_frame)
        ttk.Label(cfg_card, text="Current Environment Variables",
                  style="Section.TLabel").pack(anchor="w", pady=(0, 6))
        self.config_output = tk.Text(
            cfg_card, height=8, wrap="word", font=("monospace", 9),
            bg=LOG_BG, fg=LOG_FG, relief="solid", bd=1,
            highlightthickness=0, padx=8, pady=6)
        self.config_output.pack(fill="both", expand=True)
        self.config_output.config(state="disabled")

    # ================================================================ SSO TAB
    def _build_sso_tab(self):
        outer = ttk.Frame(self.notebook)
        self.notebook.add(outer, text="   Configure AWS SSO   ")

        canvas = tk.Canvas(outer, bg=BG, highlightthickness=0)
        scrollbar = ttk.Scrollbar(outer, orient="vertical", command=canvas.yview)
        scroll_frame = ttk.Frame(canvas)
        scroll_frame.bind("<Configure>",
                          lambda e: canvas.configure(scrollregion=canvas.bbox("all")))
        canvas.create_window((0, 0), window=scroll_frame, anchor="nw")
        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")

        # -- SSO settings card --
        card = self._card(scroll_frame)
        ttk.Label(card, text="AWS SSO Configuration",
                  style="Section.TLabel").pack(anchor="w")
        ttk.Label(card,
                  text=("Configure AWS IAM Identity Center (SSO) for Claude Code. "
                        "This will open your browser for authentication and then "
                        "let you select an account and role."),
                  style="Muted.TLabel", wraplength=680).pack(anchor="w", pady=(0, 12))

        form = tk.Frame(card, bg=CARD_BG)
        form.pack(fill="x")

        self.txt_sso_session = self._form_row_entry(form, 0, "Session Name:", "claude-code")
        self.txt_sso_url = self._form_row_entry(form, 1, "SSO Start URL:", "https://vestmark-hq.awsapps.com/start#/")
        self.cmb_sso_region = self._form_row_combo(form, 2, "SSO Region:", SSO_REGIONS, "us-east-1")
        self.txt_sso_scopes = self._form_row_entry(form, 3, "Registration Scopes:", "sso:account:access")
        self.cmb_sso_cli_region = self._form_row_combo(form, 4, "CLI Default Region:", SSO_REGIONS, "us-east-1")
        self.cmb_sso_output = self._form_row_combo(form, 5, "CLI Output Format:", ["json", "yaml", "text", "table"], "json")

        # -- Buttons --
        btn_frame = tk.Frame(scroll_frame, bg=BG)
        btn_frame.pack(fill="x", pady=(8, 0))

        self.btn_start_sso = HoverButton(
            btn_frame, PRIMARY_BTN_BG, PRIMARY_BTN_HOVER,
            text="Start SSO Configuration", command=self._on_start_sso)
        self.btn_start_sso.pack(side="left", padx=(0, 6))

        ttk.Label(
            scroll_frame,
            text=("Start SSO Configuration will open a terminal to run "
                  "'aws configure sso'. Your browser will open for authentication. "
                  "After signing in, you will select your account and role in the "
                  "terminal. SSO Login refreshes an existing SSO session."),
            style="Faint.TLabel", wraplength=720,
        ).pack(anchor="w", pady=(6, 8))

        # -- SSO log card --
        log_card = self._card(scroll_frame)
        ttk.Label(log_card, text="SSO Log",
                  style="Section.TLabel").pack(anchor="w", pady=(0, 6))
        self.sso_log = tk.Text(
            log_card, height=8, wrap="word", font=("monospace", 9),
            bg=LOG_BG, fg=LOG_FG, relief="solid", bd=1,
            highlightthickness=0, padx=8, pady=6)
        self.sso_log.pack(fill="both", expand=True)
        self.sso_log.config(state="disabled")

    # ================================================================ HELPERS
    def _card(self, parent):
        wrapper = tk.Frame(parent, bg=CARD_BORDER, padx=1, pady=1)
        wrapper.pack(fill="x", pady=(0, 10))
        card = tk.Frame(wrapper, bg=CARD_BG, padx=18, pady=14)
        card.pack(fill="both", expand=True)
        return card

    def _form_row_combo(self, parent, row, label, values, default):
        tk.Label(parent, text=label, bg=CARD_BG, fg=TEXT_SECONDARY,
                 font=("sans-serif", 10, "bold"), anchor="w").grid(
            row=row, column=0, sticky="w", padx=(0, 12), pady=4)
        var = tk.StringVar(value=default)
        combo = ttk.Combobox(parent, textvariable=var, values=values,
                             state="readonly", font=("sans-serif", 10))
        combo.grid(row=row, column=1, sticky="ew", pady=4)
        parent.columnconfigure(1, weight=1)
        return var

    def _form_row_entry(self, parent, row, label, default=""):
        tk.Label(parent, text=label, bg=CARD_BG, fg=TEXT_SECONDARY,
                 font=("sans-serif", 10, "bold"), anchor="w").grid(
            row=row, column=0, sticky="w", padx=(0, 12), pady=4)
        var = tk.StringVar(value=default)
        entry = tk.Entry(parent, textvariable=var, font=("sans-serif", 10),
                         relief="solid", bd=1)
        entry.grid(row=row, column=1, sticky="ew", pady=4)
        parent.columnconfigure(1, weight=1)
        return var

    def _form_row_entry_with_browse(self, parent, row, label, default=""):
        tk.Label(parent, text=label, bg=CARD_BG, fg=TEXT_SECONDARY,
                 font=("sans-serif", 10, "bold"), anchor="w").grid(
            row=row, column=0, sticky="w", padx=(0, 12), pady=4)
        var = tk.StringVar(value=default)
        entry = tk.Entry(parent, textvariable=var, font=("sans-serif", 10),
                         relief="solid", bd=1)
        entry.grid(row=row, column=1, sticky="ew", pady=4, padx=(0, 6))

        def browse():
            directory = filedialog.askdirectory(
                title="Select Default Project Directory",
                initialdir=var.get() if var.get() and os.path.exists(var.get()) else str(Path.home())
            )
            if directory:
                var.set(directory)

        browse_btn = HoverButton(parent, SECONDARY_BTN_BG, SECONDARY_BTN_HOVER,
                                 fg=TEXT_SECONDARY, text="Browse...", command=browse)
        browse_btn.grid(row=row, column=2, sticky="w", pady=4)

        parent.columnconfigure(1, weight=1)
        parent.columnconfigure(2, weight=0)
        return var

    def _write_log(self, log_widget, message, level="INFO"):
        stamp = datetime.now().strftime("%H:%M:%S")
        log_widget.config(state="normal")
        log_widget.insert("end", f"[{stamp}] [{level}] {message}\n")
        log_widget.see("end")
        log_widget.config(state="disabled")

    def _write_install_log(self, message, level="INFO"):
        self._write_log(self.install_log, message, level)

    def _write_sso_log(self, message, level="INFO"):
        self._write_log(self.sso_log, message, level)

    def _set_text(self, widget, text):
        widget.config(state="normal")
        widget.delete("1.0", "end")
        widget.insert("1.0", text)
        widget.config(state="disabled")

    # ================================================================ PREREQS
    def _set_prereq_status(self, tool, installed, detail=""):
        dot, label = self.prereq_rows[tool]
        if installed:
            dot.config(fg=GREEN)
            label.config(text=f"Installed - {detail}", fg=GREEN)
        else:
            dot.config(fg=RED)
            label.config(text="Not found", fg=RED)

    def _update_prerequisites(self):
        self.set_status("Checking prerequisites...")
        self.root.update_idletasks()

        git_ver = get_tool_info("git")
        self._set_prereq_status("Git", git_ver is not None, git_ver or "")
        self.git_installed = git_ver is not None

        aws_ver = get_tool_info("aws")
        self._set_prereq_status("AWS CLI", aws_ver is not None, aws_ver or "")
        self.aws_installed = aws_ver is not None

        claude_paths = [
            Path.home() / ".local" / "bin" / "claude",
            Path.home() / ".claude" / "local" / "claude",
            Path("/usr/local/bin/claude"),
        ]
        claude_ver = get_tool_info("claude")
        if claude_ver is None:
            for p in claude_paths:
                if p.exists():
                    try:
                        result = subprocess.run(
                            [str(p), "--version"], capture_output=True,
                            text=True, timeout=10)
                        out = (result.stdout or result.stderr or "").strip()
                        claude_ver = out.split("\n")[0] if out else "(found)"
                    except Exception:
                        claude_ver = "(found but version unknown)"
                    break
        self._set_prereq_status("Claude Code", claude_ver is not None, claude_ver or "")
        self.claude_installed = claude_ver is not None

        prereqs_met = self.git_installed and self.aws_installed
        self.btn_install.config(
            state="normal" if prereqs_met else "disabled")

        # Enable/disable Start Claude button based on Claude Code installation
        self.btn_start_claude.config(
            state="normal" if self.claude_installed else "disabled")

        # Enable/disable SSO buttons based on AWS CLI installation
        self.btn_start_sso.config(
            state="normal" if self.aws_installed else "disabled")
        self.btn_sso_login.config(
            state="normal" if self.aws_installed else "disabled")

        self.set_status("Ready")

    # ================================================================ EVENTS: INSTALL TAB
    def _on_start(self):
        self._update_prerequisites()
        self._load_config_into_form()
        self._write_install_log("Claude Code Assistant ready.")

    def _on_refresh(self):
        self._write_install_log("Refreshing prerequisite status...")
        self._update_prerequisites()
        self._write_install_log("Prerequisite check complete.", "OK")

    # ---- Install Git ----
    def _on_install_git(self):
        if self.git_installed:
            messagebox.showinfo("Git", "Git is already installed.")
            return
        self._run_apt_install("git", "Git")

    # ---- Install AWS CLI v2 ----
    def _on_install_aws(self):
        if self.aws_installed:
            messagebox.showinfo("AWS CLI", "AWS CLI is already installed.")
            return

        self.btn_install_git.config(state="disabled")
        self.btn_install_aws.config(state="disabled")
        self.btn_refresh.config(state="disabled")
        self.set_status("Installing AWS CLI v2...")
        self._write_install_log("Installing AWS CLI v2 from official source...")

        def _do():
            success = False
            try:
                elevator = "pkexec" if shutil.which("pkexec") else "sudo"
                install_script = (
                    'set -e; '
                    'apt-get install -y -qq curl unzip; '
                    'curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" '
                    '  -o /tmp/awscliv2.zip; '
                    'unzip -qo /tmp/awscliv2.zip -d /tmp/awscli-install; '
                    '/tmp/awscli-install/aws/install --update; '
                    'rm -rf /tmp/awscliv2.zip /tmp/awscli-install'
                )
                result = subprocess.run(
                    [elevator, "bash", "-c", install_script],
                    capture_output=True, text=True, timeout=180)
                output = (result.stdout or "") + (result.stderr or "")
                for line in output.strip().splitlines()[-10:]:
                    self.root.after(0, self._write_install_log, line.strip())
                success = result.returncode == 0
            except subprocess.TimeoutExpired:
                self.root.after(0, self._write_install_log,
                                "AWS CLI install timed out.", "ERROR")
            except Exception as e:
                self.root.after(0, self._write_install_log,
                                f"AWS CLI install failed: {e}", "ERROR")

            def _finish():
                self._update_prerequisites()
                if success:
                    self._write_install_log("AWS CLI v2 installed successfully!", "OK")
                    self.set_status("AWS CLI installed.")
                else:
                    self._write_install_log(
                        "AWS CLI installation may have failed. Click Refresh to re-check.", "WARN")
                    self.set_status("AWS CLI installation may have failed.")
                self.btn_install_git.config(state="normal")
                self.btn_install_aws.config(state="normal")
                self.btn_refresh.config(state="normal")

            self.root.after(0, _finish)

        threading.Thread(target=_do, daemon=True).start()

    def _run_apt_install(self, package, display_name, post_check_cmd=None):
        """Install a package via apt using pkexec for graphical privilege escalation."""
        self.btn_install_git.config(state="disabled")
        self.btn_install_aws.config(state="disabled")
        self.btn_refresh.config(state="disabled")
        self.set_status(f"Installing {display_name}...")
        self._write_install_log(f"Installing {display_name} (package: {package})...")

        def _do():
            success = False
            try:
                # Try pkexec first (graphical sudo prompt), fall back to sudo
                elevator = "pkexec" if shutil.which("pkexec") else "sudo"
                result = subprocess.run(
                    [elevator, "apt-get", "install", "-y", package],
                    capture_output=True, text=True, timeout=120)
                output = (result.stdout or "") + (result.stderr or "")
                for line in output.strip().splitlines()[-10:]:
                    self.root.after(0, self._write_install_log, line.strip())
                success = result.returncode == 0
            except subprocess.TimeoutExpired:
                self.root.after(0, self._write_install_log,
                                f"{display_name} install timed out.", "ERROR")
            except Exception as e:
                self.root.after(0, self._write_install_log,
                                f"{display_name} install failed: {e}", "ERROR")

            def _finish():
                self._update_prerequisites()
                if success:
                    self._write_install_log(f"{display_name} installed successfully!", "OK")
                    self.set_status(f"{display_name} installed.")
                else:
                    self._write_install_log(
                        f"{display_name} installation may have failed. Click Refresh to re-check.", "WARN")
                    self.set_status(f"{display_name} installation may have failed.")
                self.btn_install_git.config(state="normal")
                self.btn_install_aws.config(state="normal")
                self.btn_refresh.config(state="normal")

            self.root.after(0, _finish)

        threading.Thread(target=_do, daemon=True).start()

    def _on_install(self):
        self.btn_install.config(state="disabled")
        self.btn_refresh.config(state="disabled")
        self.btn_uninstall.config(state="disabled")
        self.set_status("Installing Claude Code...")
        self._write_install_log("Downloading and running official Claude Code installer...")

        def _do():
            try:
                proc = subprocess.Popen(
                    ["bash", "-c", "curl -fsSL https://claude.ai/install.sh | bash"],
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    text=True, env={**os.environ, "PATH": f"{Path.home() / '.local/bin'}:{os.environ.get('PATH', '')}"})
                for line in iter(proc.stdout.readline, ""):
                    stripped = line.rstrip()
                    if stripped:
                        self.root.after(0, self._write_install_log, stripped)
                proc.wait(timeout=180)
                if proc.returncode != 0:
                    self.root.after(0, self._write_install_log,
                                    f"Installer exited with code {proc.returncode}.", "ERROR")
            except subprocess.TimeoutExpired:
                proc.kill()
                self.root.after(0, self._write_install_log,
                                "Installer timed out after 3 minutes.", "ERROR")
            except Exception as e:
                self.root.after(0, self._write_install_log,
                                f"Install error: {e}", "ERROR")
            self.root.after(0, self._post_install)

        threading.Thread(target=_do, daemon=True).start()

    def _post_install(self):
        self._add_claude_to_path()
        self._update_prerequisites()
        if self.claude_installed:
            self._write_install_log("Claude Code installed successfully!", "OK")
            self.set_status("Claude Code installed.")
        else:
            self._write_install_log(
                "Claude Code not detected. The installer may have been cancelled.", "WARN")
            self.set_status("Installation not confirmed - click Refresh Status to re-check.")
        self._re_enable_install_buttons()

    def _re_enable_install_buttons(self):
        prereqs_met = self.git_installed and self.aws_installed
        self.btn_install.config(state="normal" if prereqs_met else "disabled")
        self.btn_refresh.config(state="normal")
        self.btn_uninstall.config(state="normal")

    def _on_uninstall(self):
        if not messagebox.askyesno("Confirm Uninstall",
                                   "Are you sure you want to uninstall Claude Code?"):
            return

        self.btn_install.config(state="disabled")
        self.btn_refresh.config(state="disabled")
        self.btn_uninstall.config(state="disabled")
        self.set_status("Uninstalling Claude Code...")
        self._write_install_log("Uninstalling Claude Code...")

        def _do():
            paths_to_remove = [
                Path.home() / ".claude",
                Path.home() / ".local" / "bin" / "claude",
            ]
            for p in paths_to_remove:
                if p.exists():
                    try:
                        if p.is_dir():
                            import shutil as _shutil
                            _shutil.rmtree(p)
                        else:
                            p.unlink()
                        self.root.after(0, self._write_install_log, f"Removed {p}")
                    except Exception as e:
                        self.root.after(0, self._write_install_log,
                                        f"Failed to remove {p}: {e}", "WARN")

            if shutil.which("npm"):
                try:
                    subprocess.run(
                        ["npm", "uninstall", "-g", "@anthropic-ai/claude-code"],
                        capture_output=True, timeout=30)
                except Exception:
                    pass

            self.root.after(0, self._post_uninstall)

        threading.Thread(target=_do, daemon=True).start()

    def _post_uninstall(self):
        self._update_prerequisites()
        self._write_install_log("Claude Code uninstalled.", "OK")
        self.set_status("Claude Code uninstalled.")
        self._re_enable_install_buttons()

    def _add_claude_to_path(self):
        claude_bin = Path.home() / ".local" / "bin"
        if not (claude_bin / "claude").exists():
            return
        current_path = os.environ.get("PATH", "")
        if str(claude_bin) not in current_path:
            os.environ["PATH"] = f"{claude_bin}:{current_path}"
        bashrc = Path.home() / ".bashrc"
        export_line = 'export PATH="$HOME/.local/bin:$PATH"'
        if bashrc.exists():
            content = bashrc.read_text()
            if ".local/bin" not in content:
                with open(bashrc, "a") as f:
                    f.write(f'\n# Claude Code\n{export_line}\n')
        else:
            with open(bashrc, "w") as f:
                f.write(f'{export_line}\n')

    # ================================================================ EVENTS: CONFIGURE TAB
    def _on_apply_config(self):
        self.btn_apply.config(state="disabled")
        self.set_status("Applying configuration...")

        try:
            profile = self.txt_profile.get().strip()
            if not profile:
                messagebox.showwarning("Validation", "AWS Profile cannot be empty.")
                return

            primary_label = self.cmb_primary.get()
            primary_tag = next(t for l, t in PRIMARY_MODELS if l == primary_label)
            small_label = self.cmb_small.get()
            small_tag = next(t for l, t in SMALL_MODELS if l == small_label)
            project_path = self.txt_project_path.get().strip()

            env_dict = {
                "CLAUDE_CODE_USE_BEDROCK": "1" if self.bedrock_var.get() else "0",
                "AWS_REGION": self.cmb_region.get(),
                "AWS_PROFILE": profile,
                "ANTHROPIC_MODEL": primary_tag,
                "ANTHROPIC_SMALL_FAST_MODEL": small_tag,
                "CLAUDE_CODE_DEFAULT_PROJECT": project_path,
            }

            write_env_file(env_dict)
            self._show_current_config()
            self.set_status("Configuration applied successfully.")
            messagebox.showinfo(
                "Configuration Applied",
                "Environment variables have been written to ~/.claude-code-env "
                "and sourced from ~/.bashrc.\n\n"
                "Open a NEW terminal for the changes to take effect.")
        except Exception as e:
            self.set_status("Error applying configuration.")
            messagebox.showerror("Error", f"Failed to apply configuration:\n{e}")
        finally:
            self.btn_apply.config(state="normal")

    def _on_load_config(self):
        self._load_config_into_form()

    def _load_config_into_form(self):
        stored = read_env_file()

        if "AWS_REGION" in stored and stored["AWS_REGION"] in REGIONS:
            self.cmb_region.set(stored["AWS_REGION"])
        if "AWS_PROFILE" in stored:
            self.txt_profile.set(stored["AWS_PROFILE"])
        if "ANTHROPIC_MODEL" in stored:
            tag = stored["ANTHROPIC_MODEL"]
            match = next((l for l, t in PRIMARY_MODELS if t == tag), None)
            if match:
                self.cmb_primary.set(match)
        if "ANTHROPIC_SMALL_FAST_MODEL" in stored:
            tag = stored["ANTHROPIC_SMALL_FAST_MODEL"]
            match = next((l for l, t in SMALL_MODELS if t == tag), None)
            if match:
                self.cmb_small.set(match)
        if "CLAUDE_CODE_DEFAULT_PROJECT" in stored:
            self.txt_project_path.set(stored["CLAUDE_CODE_DEFAULT_PROJECT"])
        if "CLAUDE_CODE_USE_BEDROCK" in stored:
            self.bedrock_var.set(stored["CLAUDE_CODE_USE_BEDROCK"] == "1")

        self._show_current_config()
        self.set_status("Loaded current environment values")

    def _show_current_config(self):
        stored = read_env_file()
        lines = ["--- Stored in ~/.claude-code-env ---"]
        for v in MANAGED_VARS:
            val = stored.get(v, "(not set)")
            lines.append(f"{v} = {val}")
        lines.append("")
        lines.append("--- Current Process Environment ---")
        for v in MANAGED_VARS:
            val = os.environ.get(v, "(not set)")
            lines.append(f"{v} = {val}")
        self._set_text(self.config_output, "\n".join(lines))

    # ================================================================ EVENTS: SSO TAB
    def _on_start_sso(self):
        session_name = self.txt_sso_session.get().strip()
        start_url = self.txt_sso_url.get().strip()
        sso_region = self.cmb_sso_region.get()
        scopes = self.txt_sso_scopes.get().strip()
        cli_region = self.cmb_sso_cli_region.get()
        out_format = self.cmb_sso_output.get()

        if not session_name or not start_url:
            messagebox.showwarning("Validation",
                                   "Session Name and SSO Start URL are required.")
            return

        self.btn_start_sso.config(state="disabled")
        self.btn_sso_login.config(state="disabled")
        self.set_status("SSO terminal opened - complete the setup there.")
        self._write_sso_log("Launching aws configure sso...")
        self._write_sso_log(f"Session: {session_name} | URL: {start_url} | Region: {sso_region}")

        aws_dir = Path.home() / ".aws"
        aws_dir.mkdir(parents=True, exist_ok=True)
        config_file = aws_dir / "config"

        sso_session_block = (
            f"[sso-session {session_name}]\n"
            f"sso_start_url = {start_url}\n"
            f"sso_region = {sso_region}\n"
            f"sso_registration_scopes = {scopes}"
        )

        content = config_file.read_text() if config_file.exists() else ""

        session_pattern = (
            r"(?s)\[sso-session " + re.escape(session_name) + r"\].*?(?=\n\[|\Z)"
        )
        if f"[sso-session {session_name}]" in content:
            content = re.sub(session_pattern, sso_session_block, content)
        else:
            content = content.rstrip() + f"\n\n{sso_session_block}\n"

        profile_pattern = (
            r"(?s)\[profile " + re.escape(session_name) + r"\].*?(?=\n\[|\Z)"
        )
        content = re.sub(profile_pattern, "", content)

        config_file.write_text(content.strip() + "\n")
        self._write_sso_log("Wrote SSO session to ~/.aws/config", "OK")

        terminal = find_terminal_emulator()
        if not terminal:
            self._write_sso_log("No terminal emulator found.", "ERROR")
            self._re_enable_sso_buttons()
            return

        sso_script = (
            f'echo "AWS SSO Configuration"; '
            f'echo "====================="; '
            f'echo ""; '
            f'echo "When prompted:"; '
            f'echo "  SSO session name  -> type: {session_name}"; '
            f'echo "  Select account    -> choose your account"; '
            f'echo "  Select role       -> choose your role"; '
            f'echo "  Default region    -> {cli_region}"; '
            f'echo "  Output format     -> {out_format}"; '
            f'echo "  Profile name      -> {session_name}"; '
            f'echo ""; '
            f'aws configure sso; '
            f'echo ""; '
            f'echo "SSO configuration complete. You may close this window."; '
            f'read -p "Press Enter to close..."'
        )

        try:
            if "gnome-terminal" in terminal:
                proc = subprocess.Popen([terminal, "--", "bash", "-c", sso_script])
            else:
                proc = subprocess.Popen([terminal, "-e", "bash", "-c", sso_script])
        except Exception as e:
            self._write_sso_log(f"Failed to launch terminal: {e}", "ERROR")
            self._re_enable_sso_buttons()
            return

        def _wait():
            proc.wait()
            self.root.after(0, self._post_sso, session_name)

        threading.Thread(target=_wait, daemon=True).start()

    def _post_sso(self, session_name):
        self._write_sso_log("SSO configuration terminal closed.")
        if AWS_CONFIG.exists():
            content = AWS_CONFIG.read_text()
            if f"profile {session_name}" in content:
                self._write_sso_log(
                    f"AWS profile '{session_name}' found in ~/.aws/config.", "OK")
                self.set_status(f"SSO profile '{session_name}' configured successfully.")
            else:
                self._write_sso_log(
                    f"AWS profile '{session_name}' not found. SSO setup may have been cancelled.", "WARN")
                self.set_status("SSO configuration may not have completed.")
        self._re_enable_sso_buttons()

    def _on_sso_login(self):
        session_name = self.txt_sso_session.get().strip()
        if not session_name:
            messagebox.showwarning("Validation", "Session Name is required.")
            return

        self.btn_start_sso.config(state="disabled")
        self.btn_sso_login.config(state="disabled")
        self.set_status("SSO login window opened - authenticate in your browser.")
        self._write_sso_log(f"Launching aws sso login --profile {session_name}...")

        terminal = find_terminal_emulator()
        if not terminal:
            self._write_sso_log("No terminal emulator found.", "ERROR")
            self._re_enable_sso_buttons()
            return

        login_script = (
            f'echo "AWS SSO Login"; '
            f'echo "============="; '
            f'echo ""; '
            f'aws sso login --profile {session_name}; '
            f'echo ""; '
            f'echo "SSO login complete. You may close this window."; '
            f'read -p "Press Enter to close..."'
        )

        try:
            if "gnome-terminal" in terminal:
                proc = subprocess.Popen([terminal, "--", "bash", "-c", login_script])
            else:
                proc = subprocess.Popen([terminal, "-e", "bash", "-c", login_script])
        except Exception as e:
            self._write_sso_log(f"Failed to launch terminal: {e}", "ERROR")
            self._re_enable_sso_buttons()
            return

        def _wait():
            proc.wait()
            self.root.after(0, self._post_sso_login)

        threading.Thread(target=_wait, daemon=True).start()

    def _post_sso_login(self):
        self._write_sso_log("SSO login terminal closed.", "OK")
        self.set_status("SSO login complete.")
        self._re_enable_sso_buttons()

    def _re_enable_sso_buttons(self):
        self.btn_start_sso.config(state="normal")
        self.btn_sso_login.config(state="normal")

    # ================================================================ EVENTS: START CLAUDE
    def _on_start_claude(self):
        self._write_install_log("=== Start Claude button clicked ===", "INFO")
        self.set_status("Launching Claude Code terminal...")

        stored = read_env_file()
        project_path = stored.get("CLAUDE_CODE_DEFAULT_PROJECT", "").strip()
        self._write_install_log(f"Project path: {project_path if project_path else '(none)'}", "INFO")

        terminal = find_terminal_emulator()
        self._write_install_log(f"Terminal found: {terminal}", "INFO")
        if not terminal:
            messagebox.showerror("Error", "No terminal emulator found.")
            self.set_status("Failed to launch Claude: no terminal found.")
            self._write_install_log("ERROR: No terminal emulator found", "ERROR")
            return

        claude_script_parts = [
            'echo "Claude Code"',
            'echo "==========="',
            'echo ""',
        ]

        if project_path and os.path.exists(project_path):
            claude_script_parts.append(f'echo "Navigating to: {project_path}"')
            claude_script_parts.append(f'cd "{project_path}"')
            claude_script_parts.append('echo ""')

        claude_script_parts.append('claude')

        claude_script = '; '.join(claude_script_parts)
        self._write_install_log(f"Claude script: {claude_script}", "INFO")

        try:
            self._write_install_log(f"Attempting to launch terminal: {terminal}", "INFO")
            if "gnome-terminal" in terminal:
                self._write_install_log("Using gnome-terminal format", "INFO")
                subprocess.Popen([terminal, "--", "bash", "-c", claude_script])
            else:
                self._write_install_log("Using standard terminal format", "INFO")
                subprocess.Popen([terminal, "-e", "bash", "-c", claude_script])
            self.set_status("Claude Code terminal launched.")
            self._write_install_log("Terminal launched successfully!", "OK")
        except Exception as e:
            self._write_install_log(f"Exception launching terminal: {e}", "ERROR")
            messagebox.showerror("Error", f"Failed to launch terminal: {e}")
            self.set_status("Failed to launch Claude.")

    # ================================================================ EVENTS: CHECK FOR UPDATES
    def _on_check_update(self):
        self.set_status("Checking for updates...")
        self._write_install_log(f"Checking for updates... (Current: v{SCRIPT_VERSION})")

        def _check():
            latest_version = get_latest_script_version()

            def _show_result():
                if latest_version is None:
                    self._write_install_log("Unable to check for updates. Check your internet connection.", "WARN")
                    self.set_status("Update check failed - connection error")
                    messagebox.showwarning(
                        "Update Check Failed",
                        "Unable to check for updates. Please verify your internet connection.\n\n"
                        "Check the Output Log for details.")
                    return

                if latest_version == "NO_VERSION_FOUND":
                    self._write_install_log("GitHub file doesn't contain version info yet.", "WARN")
                    self.set_status("GitHub file needs update")
                    messagebox.showinfo(
                        "GitHub File Not Updated",
                        "The file on GitHub doesn't contain version control information yet.\n\n"
                        "Please upload the updated local file to GitHub to enable auto-updates.")
                    return

                self._write_install_log(f"Latest version on GitHub: v{latest_version}")
                comparison = compare_versions(SCRIPT_VERSION, latest_version)

                if comparison < 0:
                    self._write_install_log(f"Update available: v{latest_version}", "OK")
                    self.set_status(f"Update available: v{latest_version}")

                    result = messagebox.askyesno(
                        "Update Available",
                        f"A new version is available!\n\n"
                        f"Current version: {SCRIPT_VERSION}\n"
                        f"Latest version: {latest_version}\n\n"
                        f"Would you like to update now?")

                    if result:
                        self._do_update(latest_version)
                elif comparison == 0:
                    self._write_install_log("You are running the latest version.", "OK")
                    self.set_status(f"Up to date (v{SCRIPT_VERSION})")
                    messagebox.showinfo(
                        "Up to Date",
                        f"You are running the latest version ({SCRIPT_VERSION}).")
                else:
                    self._write_install_log("Your version is newer than GitHub (dev version?).", "INFO")
                    self.set_status("Development version detected")
                    messagebox.showinfo(
                        "Newer Version Detected",
                        f"Your version ({SCRIPT_VERSION}) is newer than the latest on GitHub ({latest_version}).\n\n"
                        f"You may be running a development version.")

            self.root.after(0, _show_result)

        threading.Thread(target=_check, daemon=True).start()

    def _do_update(self, new_version):
        self.set_status(f"Updating to v{new_version}...")

        def _update():
            success = update_script(new_version, self._write_install_log)

            def _finish():
                if success:
                    self.set_status("Update complete - restart required")
                    result = messagebox.askyesno(
                        "Update Complete",
                        f"Script updated successfully to version {new_version}.\n\n"
                        f"Restart the application now?")

                    if result:
                        # Restart the application
                        python = sys.executable
                        os.execl(python, python, *sys.argv)
                else:
                    self.set_status("Update failed")
                    messagebox.showerror(
                        "Update Error",
                        "Failed to update script.\n\nCheck the Output Log for details.")

            self.root.after(0, _finish)

        threading.Thread(target=_update, daemon=True).start()


def main():
    root = tk.Tk()
    ClaudeCodeAssistant(root)
    root.mainloop()


if __name__ == "__main__":
    main()
