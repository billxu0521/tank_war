from pathlib import Path
p=Path(__file__).resolve().parent
for name in ['capture_trial_v008.py','capture_color_gray_v008.py','verify_pose_v008.py']:
 exec(compile((p/name).read_text(),str(p/name),'exec'))
