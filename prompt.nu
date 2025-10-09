source $"($nu.default-config-dir)/themes/catppuccin_mocha.nu"

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

def _no_powerline [] { $env.NO_POWERLINE? | default false }

def _fg_rgb [rgb] {
	$"($_ESC)[38;2;($rgb | get 0);($rgb | get 1);($rgb | get 2)m"
}

def _bg_rgb [rgb] {
	$"($_ESC)[48;2;($rgb | get 0);($rgb | get 1);($rgb | get 2)m"
}

def _hex_to_rgb [hex: string] {
	let clean = ($hex | str trim | str downcase | str replace --regex '^#' '')
	let full = if ($clean | str length) == 3 { $clean | split chars | each {|c| $c + $c } | str join '' } else { $clean }
	let six = ($full + "000000" | str substring 0..<(6))
	let caps = ($six | parse --regex '^(?P<r>[0-9a-f]{2})(?P<g>[0-9a-f]{2})(?P<b>[0-9a-f]{2})$' | get 0?)
	if ($caps == null) { return [0 0 0] }
	[($caps.r | into int --radix 16) ($caps.g | into int --radix 16) ($caps.b | into int --radix 16)]
}

let _theme = (try { $theme } catch { {} })

let _palette = {
	text: (_hex_to_rgb ($_theme.crust?))
	cwd: (_hex_to_rgb $_theme.green?)
	duration: (_hex_to_rgb $_theme.sapphire?)
	git: {
		clean: (_hex_to_rgb $_theme.green?)
		dirty: (_hex_to_rgb $_theme.peach?)
		ahead: (_hex_to_rgb $_theme.sky?)
		behind: (_hex_to_rgb $_theme.mauve?)
		diverge: (_hex_to_rgb $_theme.red?)
	}
	info: (_hex_to_rgb $_theme.teal?)
}

def _text_rgb [] {
	if ($env.PROMPT_LIGHT_TEXT? | default false) {
		_hex_to_rgb ($_theme.text? | default $_theme.crust?)
	} else {
		$_palette.text
	}
}

def _paint_face [bg_rgb, fg_rgb=null] { (_bg_rgb $bg_rgb) + (_fg_rgb ($fg_rgb | default (_text_rgb))) }

let _batt_rgb_hi = (_hex_to_rgb $_theme.green?)
let _batt_rgb_mid = (_hex_to_rgb $_theme.yellow?)
let _batt_rgb_lo = (_hex_to_rgb $_theme.red?)
let _clr_user = (_fg_rgb (_hex_to_rgb $_theme.mauve?))

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
		let state = match $status_code {
			1 => "discharging",
			2 => "ac",
			3 => "full",
			4 => "low",
			5 => "critical",
			6 => "charging",
			7 => "charging",
			8 => "charging",
			9 => "charging",
			10 => "charging",
			11 => "discharging",
			12 => "discharging",
			default => ""
		}
		let charging = $status_code in [2 3 6 7 8 9 10]
		let on_ac = $status_code in [2 3 6 7 8 9 10]
		{ percent: $pct, state: ($state | str downcase), charging: $charging, on_ac: $on_ac }
	} else {
		let bat_dirs = (['/sys/class/power_supply/BAT0', '/sys/class/power_supply/BAT1', '/sys/class/power_supply/Battery']
			| each {|p|
				let check = (do { ls $p } | complete)
				if ($check.exit_code == 0) { $p } else { null }
			}
			| where {|p| $p != null })
		let bat_dir = ($bat_dirs | get 0? | default "")
		if ($bat_dir == "") { return null }
		let cap_path = (path join [$bat_dir "capacity"])
		let cap_contents = (try { open $cap_path } catch { null })
		if ($cap_contents == null) { return null }
		let pct = ($cap_contents | str trim | into int)
		let status_path = (path join [$bat_dir "status"])
		let state_raw = (try { open $status_path } catch { "" })
		let state = ($state_raw | str trim | str downcase)
		let charging = ($state =~ 'charge' or $state == "full")
		let ac_dirs = (['/sys/class/power_supply/AC', '/sys/class/power_supply/AC0', '/sys/class/power_supply/Mains']
			| each {|p|
				let check = (do { ls $p } | complete)
				if ($check.exit_code == 0) { $p } else { null }
			}
			| where {|p| $p != null })
		let on_ac = if ($ac_dirs | is-empty) { $charging } else {
			let ac_path = (path join [($ac_dirs | get 0) "online"])
			let ac_val = (try { open $ac_path } catch { null })
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
	let ms = ($raw | default ($env.CMD_DURATION_MS? | default null) | if $in == null { return "" } else { $in | into int })
	if $ms < 1000 {
		$"($ms) ms"
	} else {
		let secs = ($ms / 1000)
		let rem = ($ms mod 1000)
		let pad = if $rem >= 100 { $rem } else if $rem >= 10 { $"0($rem)" } else { $"00($rem)" }
		$"($secs).($pad) s"
	}
}

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
	if ($env.PROMPT_DEBUG_GIT? | default false) {
		print $"[git debug] dirty=($dirty) staged=($staged) unstaged=($unstaged) untracked=($untracked) conflicts=($conflicts) ahead=($ahead) behind=($behind)"
	}
	let fg_git = (_fg_rgb (_text_rgb))
	let branch_text = $"($_icons.branch) ($branch)"
	let state = if ($ahead > 0 and $behind > 0) { "diverge" } else if $dirty > 0 { "dirty" } else if $ahead > 0 { "ahead" } else if $behind > 0 { "behind" } else { "clean" }
	let git_rgb = ($_palette.git | get $state)
	mut icons = ""
	if $dirty > 0 {
		let dirty_rgb = if $_palette.git.dirty == $git_rgb { $_palette.text } else { $_palette.git.dirty }
		$icons = $icons + $" ((_fg_rgb $dirty_rgb))($_icons.dirty)($fg_git)"
	}
	if $ahead > 0 {
		let ahead_icon = "$_icons.ahead" + ($ahead | into string)
		let ahead_rgb = if $_palette.git.ahead == $git_rgb { $_palette.text } else { $_palette.git.ahead }
		$icons = $icons + $" ((_fg_rgb $ahead_rgb))($ahead_icon)($fg_git)"
	}
	if $behind > 0 {
		let behind_icon = "$_icons.behind" + ($behind | into string)
		let behind_rgb = if $_palette.git.behind == $git_rgb { $_palette.text } else { $_palette.git.behind }
		$icons = $icons + $" ((_fg_rgb $behind_rgb))($behind_icon)($fg_git)"
	}
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

def _ordinal_suffix [day: int] {
	let teens = ($day mod 100)
	if $teens in 11..13 {
		"th"
	} else {
		match ($day mod 10) {
			1 => "st", 2 => "nd", 3 => "rd", _ => "th"
		}
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
	mut icons = [$base_icon]
	if $read_only { $icons = ($icons | append $_icons.lock) }
	let has_py_env = (not (($env.VIRTUAL_ENV? | default "") | is-empty))
	let has_py_files = (['pyproject.toml' 'requirements.txt' 'setup.py' '.venv'] | any {|file| (path join [$pwd $file]) | path exists })
	if ($has_py_env or $has_py_files) { $icons = ($icons | append $_icons.python) }
	let has_node_files = (['package.json' 'pnpm-lock.yaml' 'yarn.lock' 'bun.lockb' 'node_modules'] | any {|file| (path join [$pwd $file]) | path exists })
	if $has_node_files { $icons = ($icons | append $_icons.node) }
	$icons | str join " "
}

def _pill_segment [text: string, rgb] {
	let face = (_paint_face $rgb)
	if (_no_powerline) {
		$"($face) ($text) ($_clr_reset)"
	} else {
		let sep_fg = (_fg_rgb $rgb)
		$"($sep_fg)($_powerline.left)($face) ($text) ($_clr_reset)($sep_fg)($_powerline.right)($_clr_reset)"
	}
}

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
		let cwd_bg_rgb = $_palette.cwd
		let dur_bg_rgb = $_palette.duration
		let text_rgb = (_text_rgb)
		let cwd_face = (_paint_face $cwd_bg_rgb $text_rgb)
		let dur_face = (_paint_face $dur_bg_rgb $text_rgb)
		let dur_tokens = (_duration_tokens $duration)
		# Build seamless divide with a single seam:
		# - seam1 () uses fg=cwd_bg, bg=dur_bg; then switch to dur_fg for content
		let seam1_fg = (_fg_rgb $cwd_bg_rgb)
		let seam1_bg = (_bg_rgb $dur_bg_rgb)
		let seam1 = $"($seam1_fg)($seam1_bg)"
		if (_no_powerline) {
			$"($cwd_face) ($base_label)  ($seam1)($dur_face) ($_icons.duration)  ($dur_tokens.value) ($dur_tokens.unit) ($_clr_reset)"
		} else {
			let left_sep = (_fg_rgb $cwd_bg_rgb) + $_powerline.left
			let left_core = $"($cwd_face) ($base_label)  "
			let right_block = $"($seam1)($dur_face) ($_icons.duration)  ($dur_tokens.value) ($dur_tokens.unit) "
			let right_corner = $_clr_reset + (_fg_rgb $dur_bg_rgb) + $_powerline.right + $_clr_reset
			$"($left_sep)($left_core)($right_block)($right_corner)"
		}
	}
}

def _prompt_line1 [] {
	let segments = ([(_cwd ($env.CMD_DURATION_MS? | default null)), (_git_segment)] | where $it != "")
	if ($segments | is-empty) {
		"╭╼"
	} else {
		$"╭╼(($segments | str join ' '))"
	}
}

def _prompt_line2 [] {
	let user = ($env.USER? | default (whoami))
	$"($_clr_user)╰╼($_icons.user) ($user)($_icons.prompt)($_clr_reset) "
}

$env.PROMPT_COMMAND = { || (_prompt_line1) + "\n" + (_prompt_line2) }
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
