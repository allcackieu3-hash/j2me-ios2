#ifndef JVM_BRIDGE_H
#define JVM_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

#define JVM_BRIDGE_MAX_SLOTS 32

/// 3D supersampling scale factor (shared by M3G and MascotCapsule).
/// Set by jvm_bridge_init, read by j2me_m3g_jni.c and MC3D via system property.
extern int g_render_3d_scale;

// ============================================================
// Multi-slot JVM lifecycle
// ============================================================

/// Initialize a specific slot session (slot 0..15).
int jvm_bridge_init_slot(int slot, const char *res_root, const char *save_root, const char *midlet_jar,
                         int screen_width, int screen_height, int render_3d_scale,
                         int fps_limit);

/// Run a MIDlet in a specific slot session via MIDletRunner.
int jvm_bridge_run_midlet_slot(int slot, const char *midlet_jar_path);

/// Destroy a specific slot session and free its resources.
void jvm_bridge_destroy_slot(int slot);

/// Destroy all active slot sessions.
void jvm_bridge_destroy_all(void);

// ============================================================
// Slot focus & identification
// ============================================================

/// Set the currently focused slot (which receives input and renders to main screen).
void jvm_bridge_set_focused_slot(int slot);

/// Get the currently focused slot index.
int jvm_bridge_get_focused_slot(void);

/// Determine which slot index owns the given MiniJVM pointer.
int jvm_bridge_get_jvm_slot(void *jvm_ptr);

// ============================================================
// Slot control & status
// ============================================================

/// Request graceful MIDlet stop for a slot.
void jvm_bridge_request_stop_slot(int slot);

/// Check if stop has been requested for a slot.
int jvm_bridge_is_slot_stop_requested(int slot);

/// Check if a slot is currently active and running.
int jvm_bridge_is_slot_running(int slot);

// ============================================================
// Per-slot proxy configuration (SOCKS5 / HTTP)
// ============================================================

/// Configure proxy for a slot.
/// @param type 0 = SOCKS5, 1 = HTTP CONNECT, -1 = DIRECT (no proxy)
void jvm_bridge_set_slot_proxy(int slot, int type, const char *host, int port, const char *user, const char *pass);

/// Get configured proxy for a slot. Returns 1 if proxy is active, 0 if direct.
int jvm_bridge_get_slot_proxy(int slot, int *out_type, char *out_host, int host_len, int *out_port, char *out_user, int user_len, char *out_pass, int pass_len);

/// Forcibly disconnect active network sockets for a slot (to reconnect over new proxy).
void jvm_bridge_disconnect_slot_sockets(int slot);

// ============================================================
// Backward compatibility wrappers (default to slot 0)
// ============================================================

int jvm_bridge_init(const char *res_root, const char *save_root, const char *midlet_jar,
                    int screen_width, int screen_height, int render_3d_scale,
                    int fps_limit);

int jvm_bridge_run_midlet(const char *midlet_jar_path);

void jvm_bridge_destroy(void);

void jvm_bridge_set_save_root(const char *save_root);

void jvm_bridge_request_stop(void);

int jvm_bridge_is_stop_requested(void);

#ifdef __cplusplus
}
#endif

#endif /* JVM_BRIDGE_H */
