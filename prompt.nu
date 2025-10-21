# ── Theme configuration -----------------------------------------------------

const _theme_default_file = "catppuccin_mocha.nu"
const _theme_default_path = $"($nu.default-config-dir)/themes/($_theme_default_file)"

const _clr_reset = (ansi reset)
const _ESC = "\u{1b}"
const _powerline = { left: "" right: "" }
const _icons = {
	user: ""
	prompt: "──"
	folder: ""
	home: ""
	lock: ""
	python: ""
	node: ""
	os_apple: ""
	os_linux: ""
	os_windows: ""
	os_default: ""
	branch: ""
	dirty: ""
	ahead: ""
	behind: ""
	git_summary: "≡"
	git_staged: ""
	git_untracked: ""
	git_unstaged: ""
	git_conflict: "󰆍"
	git_separator: ""
	duration: ""
	batt_full: ""
	batt_75: ""
	batt_50: ""
	batt_25: ""
	batt_empty: ""
	batt_charge: ""
	batt_plug: "󰚥"
}

def _resolve_theme_path [file] { # resolve theme filename to absolute path
	let trimmed = ($file | default "" | str trim)
	if ($trimmed | is-empty) { return "" }
	if ($trimmed =~ '^[~\\/]' or $trimmed =~ '^[A-Za-z]:') {
		try { $trimmed | path expand } catch { $trimmed }
	} else {
		$"($nu.default-config-dir)/themes/($trimmed)"
	}
}

let _theme_file = ($env.PROMPT_THEME_FILE? | default $_theme_default_file)
let _theme_path_override = ($env.PROMPT_THEME_PATH? | default "" | str trim)
let _theme_path = ( if (not ($_theme_path_override | is-empty)) { try { $_theme_path_override | path expand } catch { $_theme_path_override } } else { (_resolve_theme_path $_theme_file) | default $_theme_default_path } )
let _theme_available = ( if ($_theme_path | is-empty) { false } else { ($_theme_path | path exists) } )

# Source default theme when present (sets $env.config.color_config)
if ($_theme_path_override | is-empty) {
	if $_theme_available {
		if ($_theme_default_path | path exists) {
			source $_theme_default_path
		}
	}
}

def _no_powerline [] { $env.NO_POWERLINE? | default false }

def _fg_rgb [rgb] { # ANSI 24-bit foreground
	$"($_ESC)[38;2;($rgb | get 0);($rgb | get 1);($rgb | get 2)m"
}

def _bg_rgb [rgb] { # ANSI 24-bit background
	$"($_ESC)[48;2;($rgb | get 0);($rgb | get 1);($rgb | get 2)m"
}

def _hex_to_rgb [hex: string] { # convert #RRGGBB/#RGB → [r g b]
	let clean = ($hex | str trim | str downcase | str replace --regex '^#' '')
	let full = if ($clean | str length) == 3 { $clean | split chars | each {|c| $c + $c } | str join '' } else { $clean }
	let six = ($full + "000000" | str substring 0..<(6))
	let caps = ($six | parse --regex '^(?P<r>[0-9a-f]{2})(?P<g>[0-9a-f]{2})(?P<b>[0-9a-f]{2})$' | get 0?)
	if ($caps == null) { return [0 0 0] }
	[($caps.r | into int --radix 16) ($caps.g | into int --radix 16) ($caps.b | into int --radix 16)]
}


def _load_theme [] { # parse `let theme = { ... }` body to record
	if (not $_theme_available) { return {} }
	let raw = (try { open --raw $_theme_path } catch { "" })
	if ($raw | str trim | is-empty) { return {} }
	let captured = ($raw | parse --regex '(?s)let\s+theme\s*=\s*(?P<body>\{.*?\})' | get 0? | default {})
	let body = ($captured.body? | default "" | str trim)
	if ($body | is-empty) { return {} }
	try { $body | from nuon } catch { {} }
}

let _theme = (scope variables | where name == "theme" | get -o 0.value | default (_load_theme))

let _fallback_theme = {
	crust: "#d7d7d7"
	text: "#d7d7d7"
	green: "#00af87"
	sapphire: "#268bd2"
	peach: "#ffaf5f"
	sky: "#5fafff"
	mauve: "#d7afff"
	red: "#ff5f5f"
	teal: "#5fd7af"
	yellow: "#ffd75f"
}

def _color_or [theme_val fallback_hex] { # theme color with hex fallback
	_hex_to_rgb ($theme_val | default $fallback_hex)
}

let _palette = {
	text: (_color_or $_theme.crust? $_fallback_theme.crust)
	cwd: (_color_or $_theme.green? $_fallback_theme.green)
	duration: (_color_or $_theme.sapphire? $_fallback_theme.sapphire)
	info: (_color_or $_theme.teal? $_fallback_theme.teal)
	git: {
		clean: (_color_or $_theme.green? $_fallback_theme.green)
		dirty: (_color_or $_theme.peach? $_fallback_theme.peach)
		diverge: (_color_or $_theme.red? $_fallback_theme.red)
		ahead: (_color_or $_theme.sky? $_fallback_theme.sky)
		behind: (_color_or $_theme.mauve? $_fallback_theme.mauve)
	}
}

def _paint_face [bg_rgb text_rgb=null] {
	(_bg_rgb $bg_rgb) + (_fg_rgb ($text_rgb | default $_palette.text))
}

let _batt_rgb_hi = (_color_or $_theme.green? $_fallback_theme.green)
let _batt_rgb_mid = (_color_or $_theme.yellow? $_fallback_theme.yellow)
let _batt_rgb_lo = (_color_or $_theme.red? $_fallback_theme.red)
let _clr_user = (_fg_rgb (_color_or $_theme.mauve? $_fallback_theme.mauve))

def _find_sys_dir [candidates: list<string>] {
	$candidates | where {|p| (try { ls $p; true } catch { false }) } | get 0? | default ""
}

# ── System information ------------------------------------------------------

def _battery_info [] {
	let os_name = ($nu.os-info.name? | default "" | str downcase)
	if ($os_name =~ "darwin|mac") {
		if (which pmset | is-empty) { return null }
		let lines_raw = (pmset -g batt | lines)
		let raw = ($lines_raw | get 1? | default "")
		let power_src = ($lines_raw | get 0? | default "")
		if ($raw | is-empty) { return null }
		let parsed = ($raw | parse --regex '(?P<pct>[0-9]{1,3})%; (?P<state>[^;]+);' | get 0? | default {})
		let pct_str = ($parsed.pct? | default "")
		if ($pct_str | is-empty) { return null }
		let p = ($pct_str | into int)
		let state = ($parsed.state? | default "" | str trim | str downcase)
		let on_ac = ($power_src | str contains "AC Power")
		let charging = if ($state == "charging") { true } else if ($state == "finishing charge") { true } else if ($state == "charged") { false } else { $on_ac and ($state != "discharging") }
		{ percent: $p, state: $state, charging: $charging, on_ac: $on_ac }
	} else if ($os_name =~ "win") {
		let pwsh = if (which pwsh | is-empty) {
			if (which powershell | is-empty) { null } else { "powershell" }
		} else { "pwsh" }
		if ($pwsh == null) { return null }
		let script = 'Get-CimInstance -ClassName Win32_Battery | Select-Object -First 1 EstimatedChargeRemaining,BatteryStatus | ConvertTo-Json -Compress'
		let res = (do { ^$pwsh "-NoProfile" "-Command" $script } | complete)
		if ($res.exit_code != 0) { return null }
		let payload = ($res.stdout | str trim)
		if ($payload | is-empty) { return null }
		let parsed = (try { $payload | from json } catch { null })
		if ($parsed == null) { return null }
		let entry = (try { $parsed | get 0 } catch { $parsed })
		if ($entry == null) { return null }
		let pct_val = ($entry.EstimatedChargeRemaining? | default null)
		if ($pct_val == null) { return null }
		let pct = ($pct_val | into int)
		let status_code = ($entry.BatteryStatus? | default 0 | into int)
		let charging_codes = [2 3 6 7 8 9 10]
		let state = if $status_code in $charging_codes {
			"charging"
		} else if $status_code in [1 11 12] {
			"discharging"
		} else {
			match $status_code { 3 => "full", 4 => "low", 5 => "critical", _ => "" }
		}
		let charging = $status_code in $charging_codes
		let on_ac = $status_code in $charging_codes
		{ percent: $pct, state: ($state | str downcase), charging: $charging, on_ac: $on_ac }
	} else {
		let bat_dir = (_find_sys_dir ['/sys/class/power_supply/BAT0' '/sys/class/power_supply/BAT1' '/sys/class/power_supply/Battery'])
		if ($bat_dir | is-empty) { return null }
		
		let cap_path = ([$bat_dir "capacity"] | path join)
		let cap_contents = (try { open $cap_path } catch { null })
		if ($cap_contents == null) { return null }
		let pct = (try { $cap_contents | str trim | into int } catch { 0 })
		
		let status_path = ([$bat_dir "status"] | path join)
		let state_raw = (try { open $status_path } catch { "" })
		let state = ($state_raw | str trim | str downcase)
		let charging = ($state =~ 'charge' or $state == "full")
		
		let ac_dir = (_find_sys_dir ['/sys/class/power_supply/AC' '/sys/class/power_supply/AC0' '/sys/class/power_supply/Mains'])
		let on_ac = if ($ac_dir | is-empty) {
			$charging
		} else {
			let ac_val = (try { open ([$ac_dir "online"] | path join) } catch { null })
			if ($ac_val == null) { $charging } else { ($ac_val | str trim) == "1" }
		}
		{ percent: $pct, state: $state, charging: $charging, on_ac: $on_ac }
	}
}

def _os_icon [] {
	let name = ($nu.os-info.name? | default "" | str downcase)
	if ($name =~ "darwin|mac") {
		$_icons.os_apple
	} else if ($name =~ "win") {
		$_icons.os_windows
	} else if ($name =~ "linux") {
		$_icons.os_linux
	} else {
		$_icons.os_default
	}
}

def _last_command_duration [raw=null] {
	let raw_duration = ($raw | default ($env.CMD_DURATION_MS? | default null))
	
	# Check if we have the bogus "0823" string that appears on fresh shell startup
	if $raw_duration == "0823" {
		# Use actual startup time instead of the bogus value
		let startup_ms = (($nu.startup-time | into int) / 1_000_000 | math round)
		if $startup_ms < 1000 {
			return $"($startup_ms) ms"
		} else {
			let secs = ($startup_ms / 1000)
			let rem = ($startup_ms mod 1000)
			let pad = if $rem >= 100 { $rem } else if $rem >= 10 { $"0($rem)" } else { $"00($rem)" }
			return $"($secs).($pad) s"
		}
	}
	
	# Convert to int for normal processing
	let ms = ($raw_duration | if $in == null { return "" } else { $in | into int })
	
	if $ms < 1000 {
		$"($ms) ms"
	} else {
		let secs = ($ms / 1000)
		let rem = ($ms mod 1000)
		let pad = if $rem >= 100 { $rem } else if $rem >= 10 { $"0($rem)" } else { $"00($rem)" }
		$"($secs).($pad) s"
	}
}

# ── Git prompt segment ------------------------------------------------------

def --env _git_segment [] {
	if (which git | is-empty) { return "" }
	let top_res = (do { git rev-parse --show-toplevel } | complete)
	if ($top_res.exit_code != 0) { return "" }
	let top = ($top_res.stdout | str trim)
	if ($top | is-empty) { return "" }

	let br_res = (do { git rev-parse --abbrev-ref HEAD } | complete)
	let branch_raw = if ($br_res.exit_code != 0) { "" } else { $br_res.stdout | str trim }
	let branch = if ($branch_raw == "" or $branch_raw == "HEAD") {
		let sh_res = (do { git rev-parse --short HEAD } | complete)
		if ($sh_res.exit_code != 0) { "detached" } else { $sh_res.stdout | str trim }
	} else { $branch_raw }

	let st_res = (do { git status --porcelain=2 --branch } | complete)
	let status = if ($st_res.exit_code != 0) { "" } else { $st_res.stdout }
	let lines = ($status | lines)
	let ab_line = ($lines | where ($it | str starts-with "# branch.ab ") | get 0 | default "")
	let ab_parsed = (if ($ab_line | is-empty) { { ahead: 0, behind: 0 } } else { $ab_line | parse "# branch.ab +{ahead} -{behind}" | get 0? | default { ahead: 0, behind: 0 } })
	let ahead = ($ab_parsed.ahead? | default 0 | into int)
	let behind = ($ab_parsed.behind? | default 0 | into int)
	# Count worktree changes: porcelain v2 lines beginning with:
	# 1 = ordinary changed entry, 2 = renamed/copied, ? = untracked, u = unmerged, S = sparse checkout modifications
	let dirty = ($lines | where {|line| $line =~ '^[12?uS] ' } | length)
	let tracked_entries = ($lines | where {|line| $line =~ '^[12] ' })
	let parsed_entries = ($tracked_entries | each {|line|
		let rec = ($line | parse --regex '^[12] (?P<X>.)(?P<Y>.) ' | get 0? | default {})
		{ X: ($rec.X? | default "."), Y: ($rec.Y? | default ".") }
	})
	let staged = ($parsed_entries | where {|row| $row.X != "." } | length)
	let unstaged_tracked = ($parsed_entries | where {|row| $row.Y != "." } | length)
	let sparse = ($lines | where {|line| $line =~ '^S ' } | length)
	let unstaged = $unstaged_tracked + $sparse
	let untracked = ($lines | where {|line| $line =~ '^\? ' } | length)
	let conflicts = ($lines | where {|line| $line =~ '^u ' } | length)
	let fg_git = (_fg_rgb $_palette.text)
	let branch_text = $"($_icons.branch) ($branch)"
	let state = if ($ahead > 0 and $behind > 0) { "diverge" } else if $dirty > 0 { "dirty" } else if $ahead > 0 { "ahead" } else if $behind > 0 { "behind" } else { "clean" }
	let git_rgb = ($_palette.git | get $state)
	
	mut icons = ""
	if $dirty > 0 { $icons = $icons + $" ((_fg_rgb (if ($_palette.git.dirty == $git_rgb) { $_palette.text } else { $_palette.git.dirty })))($_icons.dirty)($fg_git)" }
	if $ahead > 0 { $icons = $icons + $" ((_fg_rgb (if ($_palette.git.ahead == $git_rgb) { $_palette.text } else { $_palette.git.ahead })))($_icons.ahead)($ahead)($fg_git)" }
	if $behind > 0 { $icons = $icons + $" ((_fg_rgb (if ($_palette.git.behind == $git_rgb) { $_palette.text } else { $_palette.git.behind })))($_icons.behind)($behind)($fg_git)" }
	
	mut summary_parts = []
	if $staged > 0 { $summary_parts = ($summary_parts | append ($"($_icons.git_staged) ($staged)")) }
	if $untracked > 0 { $summary_parts = ($summary_parts | append ($"($_icons.git_untracked) ($untracked)")) }
	if $unstaged > 0 { $summary_parts = ($summary_parts | append ($"($_icons.git_unstaged) ($unstaged)")) }
	if $conflicts > 0 { $summary_parts = ($summary_parts | append ($"($_icons.git_conflict) ($conflicts)")) }
	let summary = (if ($summary_parts | length) > 0 {
		let joined = ($summary_parts | str join ($" ($fg_git)($_icons.git_separator) "))
		$" ($fg_git)($_icons.git_summary) ($joined)"
	} else { "" })
	if (_no_powerline) {
		return $"(char lparen)($fg_git)($branch_text)($icons)($summary)($_clr_reset)(char rparen)"
	}
	let bg = (_bg_rgb $git_rgb)
	let sep_color = (_fg_rgb $git_rgb)
	let left = $"($sep_color)($_powerline.left)"
	let branch_label = $"($fg_git) ($branch_text)"
	let core = $"($bg)($branch_label)($icons)($summary) "
	let right = $"($_clr_reset)($sep_color)($_powerline.right)"
	$"($left)($core)($right)($_clr_reset)"
}

# ── Battery & HUD widgets ---------------------------------------------------

# Battery indicator pill
def _battery_pill [] {
	let info = (_battery_info)
	if ($info == null) { return "" }
	let pct_val = ($info.percent? | default null)
	if ($pct_val == null) { return "" }
	let p = ($pct_val | into int)
	let icon = if $p >= 95 { $_icons.batt_full } else if $p >= 70 { $_icons.batt_75 } else if $p >= 45 { $_icons.batt_50 } else if $p >= 20 { $_icons.batt_25 } else { $_icons.batt_empty }
	let charging = ($info.charging? | default false)
	let on_ac = ($info.on_ac? | default $charging)
	let plug_icon = (if $charging { $_icons.batt_charge } else if $on_ac { $_icons.batt_plug } else { "" })
	let display_icon = if ($plug_icon | is-empty) { $icon } else { $plug_icon + " " + $icon }
	let bg_rgb = if $p >= 70 { $_batt_rgb_hi } else if $p >= 35 { $_batt_rgb_mid } else { $_batt_rgb_lo }
	_pill_segment ($"($display_icon)  ($p)%") $bg_rgb
}

# ── Prompt composition helpers ---------------------------------------------

def _ordinal_suffix [day: int] {
	if (($day mod 100) in 11..13) { "th" } else {
		match ($day mod 10) { 1 => "st", 2 => "nd", 3 => "rd", _ => "th" }
	}
}

def _duration_tokens [duration: string] {
	let parts = ($duration | split row ' ')
	{ value: ($parts.0? | default $duration), unit: ($parts.1? | default "") }
}

def _project_icons [pwd shown] {
	let base_icon = if ($shown | str starts-with "~") { $_icons.home } else { $_icons.folder }
	let meta = (try { metadata $pwd } catch { {} })
	let read_only = ($meta.permissions?.readonly? | default false)
	let has_py = (not (($env.VIRTUAL_ENV? | default "") | is-empty)) or (['pyproject.toml' 'requirements.txt' 'setup.py' '.venv'] | any {|f| (path join [$pwd $f]) | path exists })
	let has_node = (['package.json' 'pnpm-lock.yaml' 'yarn.lock' 'bun.lockb' 'node_modules'] | any {|f| (path join [$pwd $f]) | path exists })
	
	[$base_icon, (if $read_only { $_icons.lock }), (if $has_py { $_icons.python }), (if $has_node { $_icons.node })]
		| where {|x| $x != null and $x != "" }
		| str join " "
}

# Render a pill-shaped segment with bg color
def _pill_segment [text: string, rgb] {
	let face = (_paint_face $rgb)
	if (_no_powerline) {
		$"($face) ($text) ($_clr_reset)"
	} else {
		let sep_fg = (_fg_rgb $rgb)
		$"($sep_fg)($_powerline.left)($face) ($text) ($_clr_reset)($sep_fg)($_powerline.right)($_clr_reset)"
	}
}

# CWD segment with optional command duration
def _cwd [duration_raw=null] {
	let home = $nu.home-path
	let pwd = (pwd)
	let shown = if ($pwd | str starts-with $home) { $pwd | str replace $home "~" } else { $pwd }
	let icons_str = (_project_icons $pwd $shown)
	let duration = (_last_command_duration $duration_raw)
	let base_label = $"($icons_str)  ($shown)"
	if ($duration | is-empty) {
		(_pill_segment $base_label $_palette.cwd)
	} else {
		let cwd_bg = $_palette.cwd
		let dur_bg = $_palette.duration
		let text_rgb = $_palette.text
		let cwd_face = (_paint_face $cwd_bg $text_rgb)
		let dur_face = (_paint_face $dur_bg $text_rgb)
		let dur_tokens = (_duration_tokens $duration)
		let seam = $"((_fg_rgb $cwd_bg))((_bg_rgb $dur_bg))"
		if (_no_powerline) {
			$"($cwd_face) ($base_label)  ($seam)($dur_face) ($_icons.duration)  ($dur_tokens.value) ($dur_tokens.unit) ($_clr_reset)"
		} else {
			let left = $"((_fg_rgb $cwd_bg))($_powerline.left)($cwd_face) ($base_label)  "
			let right = $"($seam)($dur_face) ($_icons.duration)  ($dur_tokens.value) ($dur_tokens.unit) ($_clr_reset)((_fg_rgb $dur_bg))($_powerline.right)($_clr_reset)"
			$"($left)($right)"
		}
	}
}

# Top line: cwd + git segments
def _prompt_line1 [] {
	let segments = ([(_cwd ($env.CMD_DURATION_MS? | default null)), (_git_segment)] | where $it != "")
	if ($segments | is-empty) {
		"╭╼"
	} else {
		$"╭╼(($segments | str join ' '))"
	}
}

# Bottom line: user and prompt glyph
def _prompt_line2 [] {
	let user = ($env.USER? | default (whoami))
	$"($_clr_user)╰╼($_icons.user) ($user)($_icons.prompt)($_clr_reset) "
}

# Compose primary and right prompts
$env.PROMPT_COMMAND = { || (_prompt_line1) + "\n" + (_prompt_line2) }
# Right prompt: OS icon + date/time + battery
$env.PROMPT_COMMAND_RIGHT = { ||
	let now = (date now)
	let day_num = ($now | format date "%d" | into int)
	let date = $"(($now | format date "%B")) ($day_num)(_ordinal_suffix $day_num), ($now | format date "%Y")"
	let time = ($now | format date "%H:%M:%S")
	let timestamp = (_pill_segment $"((_os_icon))  ($date) ($time)" $_palette.info)
	let segments = ([$timestamp, (_battery_pill)] | where $it != "")
	$segments | str join "  "
}
$env.PROMPT_INDICATOR = { || "" }
$env.TRANSIENT_PROMPT_COMMAND = { || (_prompt_line1) + "\n" + (_prompt_line2) }
$env.TRANSIENT_PROMPT_INDICATOR = { || "" }
