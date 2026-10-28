# SCons profile for OverCut GP's web export template (Godot 4.7.2, no threads).
# The game builds its world in code: no physics, audio, networking, images,
# glTF or XR at runtime, so those modules only add download and compile time.
# platform/target/threads go on the scons command line (build_web_template.sh):
# SCons reads them before the profile and ignores them here.
production = "yes"
optimize = "size"
deprecated = "no"

disable_physics_2d = "yes"
disable_physics_3d = "yes"
disable_navigation_2d = "yes"
disable_navigation_3d = "yes"
disable_xr = "yes"

# Plain Spanish UI text: the fallback text server is enough (no ICU data).
module_text_server_adv_enabled = "no"
module_text_server_fb_enabled = "yes"

module_godot_physics_2d_enabled = "no"
module_godot_physics_3d_enabled = "no"
module_jolt_physics_enabled = "no"
module_navigation_2d_enabled = "no"
module_navigation_3d_enabled = "no"
module_openxr_enabled = "no"
module_webxr_enabled = "no"
module_mobile_vr_enabled = "no"
module_camera_enabled = "no"

module_gltf_enabled = "no"
module_fbx_enabled = "no"
module_csg_enabled = "no"
module_gridmap_enabled = "no"
module_noise_enabled = "no"
module_vhacd_enabled = "no"
module_xatlas_unwrap_enabled = "no"
module_lightmapper_rd_enabled = "no"
module_raycast_enabled = "no"
module_visual_shader_enabled = "no"
module_interactive_music_enabled = "no"

module_ogg_enabled = "no"
module_vorbis_enabled = "no"
module_theora_enabled = "no"
module_mp3_enabled = "no"

module_enet_enabled = "no"
module_multiplayer_enabled = "no"
module_websocket_enabled = "no"
module_webrtc_enabled = "no"
module_upnp_enabled = "no"
module_mbedtls_enabled = "no"
module_jsonrpc_enabled = "no"

module_bmp_enabled = "no"
module_dds_enabled = "no"
module_hdr_enabled = "no"
module_jpg_enabled = "no"
module_ktx_enabled = "no"
module_tga_enabled = "no"
module_tinyexr_enabled = "no"
module_webp_enabled = "no"
