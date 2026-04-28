# OKR 網站系統（可登入 / 可填寫目標 / 可檢視）

這個版本提供一個可直接執行的網站雛形，符合您的需求：

1. 可以登入（主管與同仁）。
2. 主管可以幫同仁新增 OKR 目標。
3. 主管可以更新年中、年底進度與 1-5 評分。
4. 同仁可登入檢視自己的目標與評分。
5. 從 2026 年開始追蹤，並可切換年度查詢。

## 快速啟動

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python app.py
```

啟動後打開：`http://127.0.0.1:5000`

## 測試帳號

- 主管：`manager1 / 123456`
- 同仁：`staff1 / 123456`
- 同仁：`staff2 / 123456`

## 系統頁面

- `/login`：登入頁
- `/dashboard`：
  - 主管：看到所有同仁與該年度 OKR 數量，可點進去管理
  - 同仁：看到自己的 OKR
- `/employee/<id>`：主管管理個人 OKR

## 資料表（SQLite）

- `employees`
- `users`
- `goals`

> 第一次啟動 `app.py` 會自動建立 `app.db`。

## 延伸建議（下一步）

- 把明碼密碼改成雜湊（bcrypt/argon2）。
- 將 SQLite 改成 PostgreSQL，套用既有 `schema.sql` 企業版資料模型。
- 加入達標率統計圖（年中/年底、部門/職能別）。
- 加入年度複製功能（2026 複製到 2027）。
