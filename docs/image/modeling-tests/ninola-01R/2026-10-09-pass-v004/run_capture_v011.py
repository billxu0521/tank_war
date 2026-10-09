from pathlib import Path
p=Path(__file__).resolve().parent
for name in ['capture_trial_baseline.py','capture_color_gray_baseline.py','capture_trial_v011.py','capture_color_gray_v011.py','verify_pose_v011.py']:
 exec(compile((p/name).read_text(),str(p/name),'exec'))
