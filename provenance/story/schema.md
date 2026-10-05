# 《雨停之前的約定》故事資料契約 v1

UTF-8 JSON。根：title、start、characters、nodes、endings、collectibles、metadata。

nodes 是以節點 id 為鍵的物件。每節點必有 speaker,text,bg,character,expression,pose,music；character 可為 null（旁白/男主無臉）；expression 僅 neutral/smile/thoughtful/sad/surprised/determined；pose 僅 standing/seated/action。cg 可為 null 或 xia_museum,xia_rooftop,xu_workshop,xu_cafe,song_station,song_rooftop；任何節點未指定 cg 代表不顯示 CG，勿延續前節點。文字 ≤220 Unicode 字元。

每節點有下列互斥之一：next 字串；choices 陣列；ending 結局 id；branches 陣列。
choices：{text,next,effects?}，effects 可含 affection:{xia:int,xu:int,song:int}、flags:[字串]、collect:[藏品id]。choices 可有 requires:{flags_all:[字串],affection_min:{xia:int}}，不符合者隱藏；至少保留一個無條件選項。
branches：依序檢查 {requires:{flags_all?,affection_min?},next}，最後必有不含 requires 的 fallback。此節點正文照常呈現，按繼續時依條件分支。
節點本身 effects（與 choices 相同）在首次進入時套用一次；讀檔重繪不重複套用。

所有路由為有向無環圖，7個 ending 節點；不以 UI 回上一句改變狀態。開始新遊戲重置 affection/flags；收藏、結局畫廊由 engine 分開持久化。

BG：museum,riverside,workshop,cafe,station,gallery,rooftop,hospital_exterior。
音樂：city,warm,reflection,ending。
角色立繪暫定每種姿勢3表情：standing=neutral/smile/thoughtful；seated=neutral/smile/sad；action=neutral/surprised/determined。若素材工人產出不同，請以 art manifest 實際可用組合回傳，我調整正文，勿靜默代用。

收集物是展覽製作用的照片與說明卡（8項），與7張結局解鎖紀錄完全分開。單次通關不必收齊。
情感結局需要路線中兩個實質互信選擇所得 flags 及明確戀愛意向；友情選項不扣分、不判失敗。選擇拒絕影像公開不扣 affection。
