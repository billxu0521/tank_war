from pathlib import Path
p=Path(__file__).resolve().parent
for name in ['capture_trial_v005.py','capture_color_gray_v005.py','verify_pose_v005.py','check_geometry_v005.py']:
 exec(compile((p/name).read_text(),str(p/name),'exec'))
