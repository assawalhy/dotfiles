#!/usr/bin/env bash
# Post-reboot verification for epic 38 (nvidia-open driver + PRIME offload).
#
# Run after rebooting generation 49, from a graphical session: the Vulkan and
# VA-API probes need the display. The script is read-only apart from the CUDA
# build under /tmp/opencode/gpu and, with GPU_VERIFY_DOCKER=1, one container
# run that pulls nvidia/cuda.
#
# Expected on success: nvidia owns the T2000 and nouveau is gone, both adapters
# appear in Vulkan, nvidia-offload shows only NVIDIA, vainfo reports the NVDEC
# profiles, the CUDA smoke prints OK, switcheroo tags the T2000 discrete, and a
# container sees the GPU.
set -u

SCRIPT_DIR=$(cd -P "$(dirname "$0")" && pwd)
WORK=/tmp/opencode/gpu
mkdir -p "$WORK"
LOG="$WORK/verify-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee "$LOG") 2>&1

pass=0
fail=0
sec() { printf '\n== %s ==\n' "$*"; }
ok() { pass=$((pass + 1)); printf 'PASS  %s\n' "$*"; }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n' "$*"; }
note() { printf '      %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

printf '# epic 38 verification, %s\n' "$(date -Is)"
printf '# system: %s\n' "$(readlink -f /run/current-system)"
printf '# log: %s\n' "$LOG"

sec session and DRM
printf 'XDG_SESSION_TYPE=%s XDG_SESSION_DESKTOP=%s\n' \
	"${XDG_SESSION_TYPE:-?}" "${XDG_SESSION_DESKTOP:-?}"
for card in /sys/class/drm/card[0-9]*; do
	[ -e "$card/device/boot_vga" ] || continue
	drv=$(basename "$(readlink -f "$card/device/driver")")
	printf '%s driver=%s boot_vga=%s\n' \
		"$(basename "$card")" "$drv" "$(cat "$card/device/boot_vga")"
done
for conn in /sys/class/drm/card[0-9]*-*/status; do
	[ -f "$conn" ] || continue
	printf '      %s %s\n' "$(basename "$(dirname "$conn")")" "$(cat "$conn")"
done
connected_card=$(grep -l '^connected' /sys/class/drm/card[0-9]*-*/status 2>/dev/null |
	sed -n '1s|/sys/class/drm/\(card[0-9]*\)-.*|\1|p')
if [ -n "$connected_card" ] &&
	[ "$(basename "$(readlink -f "/sys/class/drm/$connected_card/device/driver")")" = i915 ]; then
	ok "the panel hangs off $connected_card (i915), Intel stays primary"
else
	bad "the connected output is not on i915"
fi

sec kernel modules
for m in nvidia nvidia_modeset nvidia_drm i915; do
	if [ -d "/sys/module/$m" ]; then ok "$m loaded"; else bad "$m not loaded"; fi
done
if [ -d /sys/module/nouveau ]; then
	bad "nouveau is still loaded"
else
	ok "nouveau is not loaded"
fi
note "nvidia_drm modeset=$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null)"
note "nvidia_uvm loaded=$([ -d /sys/module/nvidia_uvm ] && echo yes || echo 'no (loads on first CUDA use)')"
head -1 /proc/driver/nvidia/version 2>/dev/null

sec nvidia-smi
if have nvidia-smi; then
	smiv=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>&1)
	nvidia-smi --query-gpu=name,driver_version,memory.total,compute_cap \
		--format=csv,noheader 2>&1
	case "$smiv" in
	595.71.05*) ok "driver 595.71.05 is live on the T2000" ;;
	*) bad "nvidia-smi reports driver '$smiv', expected 595.71.05" ;;
	esac
else
	bad "nvidia-smi not on PATH"
fi

sec nvidia-offload wrapper environment
if have nvidia-offload; then
	oenv=$(nvidia-offload printenv 2>&1 |
		grep -E '^(__NV_PRIME_RENDER_OFFLOAD|__NV_PRIME_RENDER_OFFLOAD_PROVIDER|__GLX_VENDOR_LIBRARY_NAME|__VK_LAYER_NV_optimus)=' || true)
	if [ -n "$oenv" ]; then
		printf '%s\n' "$oenv" | sed 's/^/      /'
		ok "nvidia-offload runs and sets the PRIME offload variables"
	else
		bad "the offload wrapper exports nothing"
	fi
else
	bad "nvidia-offload not on PATH"
fi

sec "Vulkan, default (both adapters expected)"
if have vulkaninfo; then
	devices=$(vulkaninfo --summary 2>/dev/null | sed -n 's/.*deviceName *= *//p')
	printf '%s\n' "$devices" | sed 's/^/      /'
	n=$(printf '%s\n' "$devices" | grep -c .)
	if [ "$n" -ge 2 ] &&
		printf '%s\n' "$devices" | grep -qiE 'nvidia|quadro|t2000' &&
		printf '%s\n' "$devices" | grep -qi 'intel'; then
		ok "vulkaninfo lists $n adapters including NVIDIA and Intel"
	else
		bad "vulkaninfo lists $n adapters (expected NVIDIA and Intel)"
	fi
else
	bad "vulkaninfo not on PATH"
fi

sec "Vulkan pinned to the NVIDIA card (switcheroo mechanism)"
# The driver's implicit optimus layer (VK_LAYER_NV_optimus) is loaded by loader
# 1.4.341 but no longer filters devices, so nvidia-offload alone still lists
# every adapter. VK_LOADER_DRIVERS_SELECT is what switcheroo-control exports for
# the discrete GPU and what GNOME's menu entry relies on.
if have vulkaninfo; then
	odev=$(VK_LOADER_DRIVERS_SELECT='*nvidia*' vulkaninfo --summary 2>/dev/null |
		sed -n 's/.*deviceName *= *//p')
	printf '%s\n' "$odev" | sed 's/^/      /'
	on=$(printf '%s\n' "$odev" | grep -c .)
	if [ "$on" -eq 1 ] && printf '%s\n' "$odev" | grep -qiE 'nvidia|quadro|t2000'; then
		ok "VK_LOADER_DRIVERS_SELECT pins the NVIDIA adapter"
	else
		bad "VK_LOADER_DRIVERS_SELECT shows $on adapters"
	fi
fi

sec VA-API (each card on its own driver)
note "LIBVA_DRIVER_NAME=${LIBVA_DRIVER_NAME:-<unset>} NVD_BACKEND=${NVD_BACKEND:-<unset>}"
if [ -n "${LIBVA_DRIVER_NAME:-}" ]; then
	bad "LIBVA_DRIVER_NAME is set session wide; that decodes on one GPU while the"
	bad "compositor runs on the other and freezes Chromium video playback"
else
	ok "no session wide LIBVA_DRIVER_NAME override"
fi
if have vainfo; then
	for dev in /dev/dri/renderD128 /dev/dri/renderD129; do
		[ -e "$dev" ] || continue
		vid=$(udevadm info --query=property "$dev" 2>/dev/null |
			sed -n 's/^ID_PATH=pci-0000:\(.*\)$/\1/p')
		printf '%s\n' "      $dev ($vid):"
		vinfo=$(vainfo --display drm --device "$dev" 2>&1)
		printf '%s\n' "$vinfo" |
			grep -E 'Driver version|error|failed' | sed 's/^/        /'
		if printf '%s\n' "$vinfo" | grep -qi 'VAProfileH264.*High' &&
			printf '%s\n' "$vinfo" | grep -qi 'VAProfileHEVCMain'; then
			ok "  $dev reports H.264 and HEVC decode"
		else
			bad "  $dev has no H.264/HEVC decode entrypoints"
		fi
	done
else
	bad "vainfo not on PATH"
fi

sec GNOME session environment
gpid=$(pgrep -x gnome-shell | head -1)
if [ -n "$gpid" ]; then
	if tr '\0' '\n' <"/proc/$gpid/environ" |
		grep -qE '^(LIBVA_DRIVER_NAME|NVD_BACKEND)='; then
		bad "gnome-shell still carries a VA-API override (pid $gpid)"
	else
		ok "gnome-shell has no VA-API override (pid $gpid)"
	fi
else
	note "gnome-shell is not running"
fi

sec CUDA
if have nvcc; then
	# nvcc does not know about the cudart store path, so find it in the system
	# closure and pass the include and library dirs explicitly.
	cudart=$(nix-store -qR /run/current-system 2>/dev/null |
		grep -m1 'cuda.*cuda_cudart-[0-9]' || true)
	note "cudart: ${cudart:-not found in /run/current-system}"
	if nvcc "$SCRIPT_DIR/cuda-smoke.cu" -o "$WORK/cuda-smoke" \
		${cudart:+-I"$cudart/include" -L"$cudart/lib"} \
		${cudart:+-Xlinker -rpath -Xlinker "$cudart/lib"} 2>"$WORK/nvcc.log"; then
		note "compiled with nvcc (log: $WORK/nvcc.log)"
		if out=$("$WORK/cuda-smoke" 2>&1); then
			printf '%s\n' "$out" | sed 's/^/      /'
			if printf '%s\n' "$out" | tail -1 | grep -qx OK; then
				ok "the CUDA smoke test computed its vector sum"
			else
				bad "the CUDA smoke test did not end with OK"
			fi
		else
			bad "the CUDA smoke test failed at run time"
			printf '%s\n' "$out" | sed 's/^/      /'
		fi
	else
		bad "nvcc failed, see $WORK/nvcc.log"
		tail -5 "$WORK/nvcc.log" | sed 's/^/      /'
	fi
else
	bad "nvcc not on PATH"
fi
note "nvidia_uvm loaded=$([ -d /sys/module/nvidia_uvm ] && echo yes || echo no)"

sec container toolkit
if systemctl is-active --quiet nvidia-container-toolkit-cdi-generator.service; then
	ok "the CDI generator service is active"
else
	bad "the CDI generator service is $(systemctl is-active nvidia-container-toolkit-cdi-generator.service)"
fi
ls -l /var/run/cdi/ /etc/cdi/ 2>&1 | sed 's/^/      /'
if [ "${GPU_VERIFY_DOCKER:-0}" = 1 ]; then
	note "pulling and running the CUDA base image, this takes a while"
	if dout=$(docker run --rm --device nvidia.com/gpu=all nvidia/cuda:12.9.0-base-ubuntu24.04 \
		nvidia-smi -L 2>&1); then
		printf '%s\n' "$dout" | sed 's/^/      /'
		ok "docker run --device nvidia.com/gpu=all reached the GPU"
	else
		printf '%s\n' "$dout" | sed 's/^/      /'
		bad "the docker GPU check failed"
	fi
else
	note "skipped, set GPU_VERIFY_DOCKER=1 to run it"
fi

sec switcheroo
if have switcherooctl; then
	slist=$(switcherooctl list 2>&1)
	printf '%s\n' "$slist" | sed 's/^/      /'
	if printf '%s\n' "$slist" | grep -q 'Device: 1'; then
		ok "switcheroo lists both GPUs"
	else
		bad "switcheroo lists fewer than two GPUs"
	fi
	if printf '%s\n' "$slist" | grep -q 'Discrete: yes'; then
		ok "switcheroo tags the T2000 discrete"
	else
		bad "switcheroo does not tag the T2000 discrete (30-discrete-gpu.rules)"
	fi
	if busctl get-property net.hadess.SwitcherooControl /net/hadess/SwitcherooControl \
		net.hadess.SwitcherooControl HasDualGpu 2>/dev/null | grep -q true; then
		ok "HasDualGpu is true, GNOME's Launch Using Discrete Graphics Card shows"
	else
		bad "HasDualGpu is not true"
	fi
else
	bad "switcherooctl not on PATH"
fi

printf '\n== summary ==\n%d passed, %d failed\n' "$pass" "$fail"
printf 'log: %s\n' "$LOG"
[ "$fail" -eq 0 ]
