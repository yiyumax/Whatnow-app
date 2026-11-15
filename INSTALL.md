# 「現在該做什麼」安裝教學

給第一次做這件事的人。照順序做，全部做完大約 1 小時，之後就不太需要再碰電腦。

你需要：

- iPhone（iOS 17 以上，本教學以 iOS 27 為準）、有設定螢幕密碼
- Windows 11 電腦、一條傳輸線
- 一個 Apple 帳號（免費的就可以）
- 一個 GitHub 帳號（免費）
- Wi‑Fi（SideStore 安裝和重簽都需要 Wi‑Fi，行動網路不行）

整個流程分四段：

| 段落 | 做什麼 | 多久做一次 |
|---|---|---|
| A | 把程式碼放上 GitHub，讓它在雲端編譯出 `.ipa` | 一次 |
| B | 在 iPhone 裝 SideStore，再用它裝這個 App | 一次 |
| C | 用「捷徑」每天自動重簽 | 一次 |
| D | 以後改了程式碼要更新 | 每次改版 |

---

## A. 放上 GitHub 並編譯

### A1. 建立 GitHub 帳號

到 <https://github.com> 註冊並登入。

### A2. 安裝 GitHub Desktop

這台電腦沒有裝 Git，用 GitHub Desktop 最簡單（它自己內建 Git）。

1. 到 <https://desktop.github.com> 下載、安裝。
2. 打開後用你的 GitHub 帳號登入。

### A3. 把專案資料夾變成 repo 並上傳

1. GitHub Desktop 選 **File → Add local repository…**，選這個專案的資料夾（裡面有 `project.yml` 的那一層）。
2. 它會說「這不是 Git repository」，點訊息裡的 **create a repository**，然後按 **Create repository**。
3. 按上方的 **Publish repository**。
   - 名稱例如 `whatnow`。
   - **「Keep this code private」請取消勾選**（設成公開）。原因：公開 repo 的 GitHub Actions 免費不限量，而且 iPhone 不用登入就能下載 `.ipa`。
   - 公開代表別人看得到程式碼，包含 `DefaultSchedule.swift` 裡的預設行程。如果介意，可以保持私人，但 macOS 編譯會消耗每月的免費額度（一次編譯大約算 50–80 分鐘的額度，每月 2000 分鐘），而且 iPhone 下載時要先在 Safari 登入 GitHub。
4. 按 **Publish repository**。

### A4. 看它編譯

1. 用瀏覽器打開 `https://github.com/你的帳號/whatnow`。
2. 點上方的 **Actions**。上傳後會自動開始一個叫 **Build IPA** 的工作。
3. 黃色圓圈是進行中，綠色勾勾是成功（大約 5–10 分鐘）。
4. 如果是紅色叉叉，點進去看是哪一步失敗：
   - 「跑核心邏輯的單元測試」失敗：時間表邏輯有錯，App 不會被編譯。
   - 「編譯（不簽名）」失敗：程式碼有編譯錯誤。
   - 把紅字訊息複製下來問 Claude。

想手動再編一次：**Actions → Build IPA → Run workflow**。

### A5. 在 iPhone 上下載 `.ipa`

1. 在 iPhone 的 Safari 打開 `https://github.com/你的帳號/whatnow/releases/latest`。
2. 在 **Assets** 底下點 **WhatNow.ipa**，選「下載」。
3. 檔案會存到「檔案」App 的「下載項目」。先放著，B 段會用到。

---

## B. 第一次設定 SideStore

以下依照 SideStore 官方文件（2026 年 11 月的版本）。步驟如果和你看到的畫面不同，以官方為準：

- 事前準備：<https://docs.sidestore.io/docs/installation/prerequisites>
- 安裝：<https://docs.sidestore.io/docs/installation/install>
- 配對檔：<https://docs.sidestore.io/docs/advanced/pairing-file>
- 常見問題：<https://docs.sidestore.io/docs/faq>

> 關於「配對檔」：以前要自己用工具產生配對檔再傳到手機。現在官方的安裝工具 **iloader** 會在安裝 SideStore 時自動幫你產生並放好，不用手動處理。

### B1. iPhone：安裝本機 VPN

1. 在 App Store 搜尋並安裝 **LocalDevVPN**。
2. 打開它，按 **Connect**。跳出「允許加入 VPN 設定」就按允許、輸入密碼。

這個 VPN 只連到手機自己，不會連到外部伺服器。SideStore 每次安裝、更新、重簽 App 時都需要它開著。

### B2. 電腦：安裝 iTunes 和 iloader

1. 從 Microsoft Store 安裝 **iTunes**（官方說如果 iTunes 不行，改裝 **Apple Devices**）。
2. 到 <https://iloader.app> 下載 Windows 版的 **MSI** 安裝檔並安裝。
   - iloader 只從 <https://iloader.app> 或 <https://github.com/nab138/iloader> 下載，不要用其他網站的。

### B3. 電腦：用 iloader 安裝 SideStore

1. 用傳輸線把 iPhone 接上電腦。iPhone 跳出「信任這部電腦？」按 **信任**、輸入密碼。
2. 打開 iloader。
3. 用你的 Apple 帳號登入（大小寫要完全正確）。
4. 選你的 iPhone。
5. 按 **Install SideStore (Stable)**，等它跑完。

### B4. iPhone：信任開發者、開啟開發者模式

1. **設定 → 一般 → VPN 與裝置管理**，在「開發者 App」底下點你的 Apple 帳號，按 **信任**。
2. **設定 → 隱私權與安全性 → 開發者模式**，打開，手機會重新開機。開機後跳出確認視窗，按 **開啟**。
   - 如果找不到「開發者模式」，先點一次桌面上的 SideStore 圖示再回來看。

### B5. iPhone：第一次開啟 SideStore

1. 打開 **LocalDevVPN**，按 **Connect**。
2. 打開 **SideStore**，用**和 iloader 同一個** Apple 帳號登入。
3. 點下方的 **My Apps**。
4. 點 SideStore 旁邊的 **7 DAYS**，手動重簽一次。如果問要不要撤銷或建立新的簽署憑證，選 **Yes** 或 **Refresh Now**。
5. SideStore 會把你帶回主畫面，幾秒後就能再打開。

**這一步不要跳過。** 官方說明：剛裝好時 SideStore 用的是 iloader 的群組 ID，重簽一次才會換成它自己的。如果先裝別的 App 再重簽，那些 App 會從清單裡消失。

### B6. iPhone：安裝「現在該做什麼」

1. 確認 LocalDevVPN 是連線狀態。
2. SideStore → **My Apps** → 左上角的 **+**。
3. 在「檔案」裡選 A5 下載的 **WhatNow.ipa**。
4. 等它裝完，桌面會出現「現在該做什麼」。

### B7. 確認 App 和小工具有共用資料

SideStore 用免費帳號簽名時，會把 App 的識別碼改成 `com.whatnow.app.你的TeamID`，共用群組也會改名。App 已經處理了這件事，但第一次請確認：

1. 打開「現在該做什麼」→ 下方 **設定**。
2. 「和小工具共用資料」應該顯示綠色的 **正常**，下面有一行 `group.com.whatnow.app.XXXXXXXXXX`。
3. 長按桌面空白處 → 左上角 **編輯 → 加入小工具** → 找「現在該做什麼」，加一個到桌面。
4. 回 App 的「編輯」改一個行程名稱，回桌面看小工具有沒有跟著變。

如果顯示紅色的「失敗」：在 SideStore 把這個 App 移除後重新安裝一次。還是失敗的話，把設定頁截圖，連同 GitHub Actions「打包成 .ipa」那一步的紀錄一起拿去問 Claude。

### 免費帳號的限制

- 同時最多 3 個側載 App。SideStore 佔 1 個，這個 App 佔 1 個，還剩 1 個。
- 每 7 天最多登記 10 個 App ID。這個 App 用掉 2 個（主 App 和小工具）。**更新同一個 App 不會再多用**，但反覆「移除再重裝不同的 App」會把額度用完，用完要等 7 天。
- 簽名 7 天到期，到期前要重簽（C 段讓它自動做）。到期了 App 會打不開，但資料還在，重簽後就恢復。

---

## C. 用「捷徑」每天自動重簽

目標：每天固定時間自動「開 VPN → SideStore 重簽全部 App → 關 VPN」，不用你按任何東西。

官方文件沒有專門講捷徑的頁面，以下是社群通用的做法。**動作的名稱以你手機上實際看到的為準**（SideStore 和 LocalDevVPN 改版時可能改名）。

為什麼要拆成兩個自動化：SideStore 重簽到最後會重裝它自己，捷徑常常在這裡被中斷，所以排在「重簽」後面的動作不一定會執行。把「關 VPN」獨立成另一個晚幾分鐘的自動化最穩。

### C1. 先確認有哪些動作可用

1. 打開「捷徑」App → 下方 **捷徑** → 右上角 **+**。
2. 在搜尋欄打 `SideStore`。應該會看到 **Refresh All Apps**（或中文「重新整理所有 App」之類）。記下它的名稱。
3. 再搜尋 `VPN`。會看到下面其中一種，記下你有的是哪一種：
   - 系統內建的 **設定 VPN**（Set VPN）：可以選「連接／中斷連接」和要用哪一個 VPN。
   - **LocalDevVPN** 自己提供的動作（如果有）。
4. 這個測試用的捷徑不用存，直接離開。

### C2. 自動化一：開 VPN 並重簽

1. 「捷徑」App → 下方 **自動化** → 右上角 **+**。
2. 選 **特定時間**。
   - 時間：選一個手機通常**連著 Wi‑Fi** 的時間，例如 `07:30`。
   - 重複：**每天**。
   - 選 **立即執行**，並把「執行時通知」關掉。
3. 按 **下一步** → **新增空白自動化**。
4. 加入動作，順序如下：
   1. **設定 VPN**：設成「連接」，VPN 選 **LocalDevVPN**。
   2. **等待**：`5` 秒（讓 VPN 連上）。
   3. **Refresh All Apps**（SideStore 的動作）。
5. 按 **完成**。

### C3. 自動化二：關 VPN

1. 再新增一個自動化 → **特定時間** → 比上一個晚 10 分鐘，例如 `07:40` → **每天** → **立即執行**。
2. 動作只有一個：**設定 VPN**，設成「中斷連接」，VPN 選 **LocalDevVPN**。
3. 按 **完成**。

（VPN 一直開著其實也沒關係，它只連到手機自己。不想弄第二個自動化的話可以省略。）

### C4. 確認自動化有成功

先手動測一次：

1. 「捷徑」→ **自動化** → 點自動化一 → 右下角的 **▶ 執行**。
2. 如果跳出「操作時間過長」之類的錯誤，先不要當成失敗。這是上面說的「SideStore 重裝自己」造成的，重簽通常已經完成。
3. 打開 SideStore → **My Apps**，看每個 App 旁邊的天數：
   - 回到 **7 DAYS** 代表成功。
4. SideStore → **Settings** → 找 **View Refresh Attempts**（重新整理紀錄），最新一筆應該是 **Success**。

隔天再看一次那個紀錄，確認排定的時間有一筆新的 Success。

如果排定時間沒有成功：

- 那個時間手機可能沒連 Wi‑Fi，或是鎖著螢幕時系統不讓它開 App。把時間改到你通常在用手機的時候（例如起床後、睡前）。
- 確認自動化是「立即執行」，不是「執行前先詢問」。
- 就算連續幾天失敗也不用緊張：簽名有 7 天，只要 7 天內成功一次就好。到期前也可以手動開 VPN，在 SideStore 的 My Apps 按 **Refresh All**。

---

## D. 以後改程式碼要怎麼更新

### D1. 更新前先備份行程（建議）

App → **匯入匯出** → **匯出成檔案**，存到「檔案」App。正常更新不會動到資料，這只是保險。

### D2. 改程式碼並上傳

1. 在電腦上改好程式碼（例如請 Claude 改）。
2. 打開 GitHub Desktop，左邊會列出改過的檔案。
3. 左下角 **Summary** 打一句說明（例如「調整小工具字體」），按 **Commit to main**。
4. 按上方的 **Push origin**。
5. GitHub 會自動重新編譯。到 **Actions** 等綠色勾勾。

### D3. 在 iPhone 上更新

1. Safari 打開 `https://github.com/你的帳號/whatnow/releases/latest`，下載新的 **WhatNow.ipa**。
2. 打開 LocalDevVPN，按 Connect。
3. SideStore → **My Apps** → 左上角 **+** → 選新的 `WhatNow.ipa`。
4. SideStore 會認出這是同一個 App，直接蓋過去更新。

### 怎樣才不會弄丟行程資料

行程存在 App 和小工具的共用空間裡。只要遵守下面三點，更新後資料都會在：

1. **不要先刪掉 App 再裝。** 直接用 SideStore 裝新的 `.ipa` 蓋過去。刪掉 App 會連資料一起刪。
2. **不要改 Bundle ID 和 App Group。** 也就是不要動 `project.yml` 裡的 `com.whatnow.app`、`com.whatnow.app.widget`，以及 `Config/*.entitlements` 裡的 `group.com.whatnow.app`。改了之後 iPhone 會把它當成另一個 App，舊資料讀不到，還會多用掉 App ID 額度。
3. **一直用同一個 Apple 帳號簽名。** 換帳號的話 Team ID 不同，群組名稱也會變。

萬一資料真的不見了：App → **匯入匯出** → **從「檔案」選擇**，選 D1 備份的檔案就能還原。

### 只是想改行程？

不用改程式碼。直接在 App 的 **編輯** 頁改，或是用 **匯入匯出** 貼上 JSON。格式和 Scriptable 版本一樣，舊的 JSON 可以直接貼進來。

---

## 常見問題

**小工具的倒數到 0 之後會怎樣？**
停在 0，不會往上數。小工具一次排好未來 48 小時每個時段的切換時間，到點由系統自動換成下一個行程。

**小工具顯示的是預設行程，不是我改過的。**
到 App 的「設定」看「和小工具共用資料」是不是「正常」。如果是「失敗」，照 B7 處理。

**SideStore 說配對檔有問題（pairing file）。**
iOS 更新或重置後配對檔可能失效。把手機接回電腦，打開 iloader：**Delete Stored Pairing** → 選裝置並在手機按信任 → **Manage Pairing File** → SideStore 旁邊按 **Place**。詳見 <https://docs.sidestore.io/docs/advanced/pairing-file>。

**App 打不開，圖示變灰。**
簽名過期了。開 LocalDevVPN，進 SideStore 的 My Apps 按 Refresh All，資料不會不見。

**行程通知沒有響。**
App →「設定」確認「行程開始時通知」有開，並到 iPhone 的「設定 → 通知 → 現在該做什麼」確認允許通知。iOS 最多只能排 64 個通知，超過的話設定頁會告訴你有幾個沒排進去。
