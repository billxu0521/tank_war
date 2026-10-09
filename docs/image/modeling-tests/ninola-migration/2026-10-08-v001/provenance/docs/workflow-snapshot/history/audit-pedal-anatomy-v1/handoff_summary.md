# Pedal Anatomy Audit v1 Handoff Summary

## Goal
分辨bone-chain結構與distal pedal外部morphology，細分溝通區，保護rear digit candidate。

## What changed
沒有模型修改。保留v1所有26個Region ID，新增24個pedal子ID（包含合併未決MAIN_TOES_SHARED）。本輪任何Shape Key values均未改。

## Method
Actual bones、vertex-group family weights、d_claw材質與既有faces/split positions建立map；temporary evaluated display輸出7圖。Ground因果僅讀取既有G0資料，未切換目前values。

## Safety / Reversibility
Source SHA與完整fingerprint前後一致；no Edit Mesh / keys / Pose / Weight / Apply / Bake / Save / new Vertex Groups。checkpoint index不變；approved01J保持P1/G.8。

## Deliverables
Pedal Region Map v2、7張Side/Top/Front/Bottom/envelope/toe/rear-candidate圖、pedal_anatomy_audit_v1.md、分區證據與validation。固定Pedal Anatomy Gate寫入report及workflow。

## Known Issues / Limitations
Latest readable Side annotation未取得，Blue/Red guide依文字，Green exact correspondence unknown。Dew骨與後向candidate存在但非confirmed hallux。Toe bones兩段近共線、claws尖楔；骨鏈正確不能證明外形Gate通過。厚surface可作後續review候選但未證明安全削薄；Ground.8既有少量穿地/接口相交保留。

## Work Status
Status audit_pending_review。RVI-001/002未變；原register沒有003，依使用者本次指示補登RVI-003 OPEN。不新增造型Pass或approved checkpoint，完成後停止。
