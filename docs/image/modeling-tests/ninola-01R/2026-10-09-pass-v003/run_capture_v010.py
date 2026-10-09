from pathlib import Path
p=Path(__file__).resolve().parent
for name in ['capture_trial_v010.py','capture_color_gray_v010.py','verify_pose_v010.py']:
 exec(compile((p/name).read_text(),str(p/name),'exec'))
