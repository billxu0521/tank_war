# Asset manifest usage

ASSET_MANIFEST.csv indexes every payload file with archive-root-relative path, actual source, role/status, software, checks and SHA256. Filename and location are actual, not fabricated.
01J=current approved production; K6v003=selected candidate not production; allK7=rejected experiments. Earlierapprovedcheckpointsretainhistoricalapproval. Historicalworking labels are snapshots, supersededbyHANDOFFdecisionforcurrentcontinuation.

SHA256SUMS.txt covers allpayload files including CSV and thisdocument, excluding itself (normal checksum-list convention). CSV itself is excludedfromitsownrows toavoidrecursiveselfhash. ZIP ownhash is provided beside ZIP. Source localabsolute paths in historical/user-provenance columns are notcanonicalportableasset paths.

Thearchive is a copy-only handoff, notasecondcanonicalmodelbranch andnotfullGitclone. `assets/repository/` mirrorpathsand `docs/key_assets.json` maptheoriginalcanonicalrepo paths toarchive copies. Existing raw/source manifests may mentionuncopied historicalPNGframes; review is deliberatelycurated. Noimportant model or required annotationisomitted.
