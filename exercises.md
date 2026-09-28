# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: điền câu trả lời trực tiếp dưới mỗi câu hỏi.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Trần Anh Quân  Mã học viên: 2A202602598

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Nếu cấu hình giá trị mặc định là `"changeme"`, khi triển khai lên production mà người vận hành quên cấu hình biến môi trường `AGENT_API_KEY`, ứng dụng vẫn khởi động bình thường và liveness probe báo 200 OK. Khi đó, bất kỳ ai cũng có thể gửi request với header `X-API-Key: changeme` để gọi API `/ask`, gây cạn kiệt ngân sách LLM và rò rỉ dữ liệu.
Với cơ chế "Fail fast" (không gán giá trị mặc định), Pydantic sẽ ném ngoại lệ ValidationError và ứng dụng lập tức crash ngay khi khởi động. Orchestrator (Docker/Railway/Kubernetes) sẽ phát hiện container không khởi động thành công và dừng quá trình rollout ngay lập tức, giúp kỹ sư phát hiện và khắc phục thiếu sót cấu hình trước khi dịch vụ tiếp xúc với người dùng bên ngoài.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log JSON thu được:
```json
{"timestamp": "2026-09-28T08:51:36.142857Z", "level": "info", "event": "ask_completed", "user_id": "sv-test", "tokens_in": 43, "tokens_out": 47, "cost_usd": 0.00003465}
```

Hai việc làm được với dòng log có cấu trúc trên:
1. **Phân tích và tổng hợp số liệu tự động (Automated Metrics & Aggregation):** Các hệ thống log tập trung (như Datadog, Grafana Loki, ELK stack) có thể tự động trích xuất các trường để tính toán tổng chi phí LLM theo từng `user_id` (`SUM(cost_usd)`), theo dõi lượng token trung bình (`AVG(tokens_in)`), hoặc dựng dashboard giám sát chi phí theo thời gian thực mà không cần viết regex bóc tách chuỗi phức tạp.
2. **Cảnh báo tức thời và truy vết sự cố (Alerting & Traceability):** Có thể dễ dàng thiết lập cảnh báo khi `cost_usd` của một request vượt ngưỡng bất thường, hoặc lọc nhanh toàn bộ lịch sử request của một `user_id` cụ thể để điều tra lạm dụng, trong khi lệnh `print("đã trả lời xong")` hoàn toàn thiếu thông tin định danh và số liệu để giám sát.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 884 MB |
| Multi-stage | 271 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần dung lượng chênh lệch (giảm hơn 600 MB) đến từ các thành phần chỉ cần thiết trong quá trình build nhưng không cần cho runtime:
1. Bộ nhớ đệm của pip (`/root/.cache/pip`) và các tệp wheel tải về trong quá trình cài đặt.
2. Các công cụ build dependencies (gcc, make, header files C/Python nếu có biên dịch native extensions).
3. Các tệp tạm, tài liệu, test suite kèm theo trong mã nguồn của các thư viện bên thứ ba.
Ở mô hình multi-stage, stage `runtime` chỉ copy duy nhất thư mục đích `/install` (chứa các package đã build xong) sang một base image sạch `python:3.11-slim`, loại bỏ hoàn toàn các rác build thừa thãi.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

- Với Dockerfile hiện tại:
  - Tất cả các layer trước đó (từ base image, `WORKDIR`, `COPY requirements.txt .`, tới `RUN pip install ...`) đều được tái sử dụng hoàn toàn từ cache (`CACHED`) vì tệp `requirements.txt` không thay đổi.
  - Chỉ có layer `COPY app ./app` và các chỉ thị tiếp theo (`USER appuser`, `EXPOSE`, `CMD`) phải chạy lại. Toàn bộ quá trình build chỉ mất 1-2 giây.
- Nếu đặt `COPY . .` lên trước `RUN pip install`:
  - Mỗi khi thay đổi dù chỉ một ký tự trong `app/main.py`, checksum của build context thay đổi khiến layer `COPY . .` bị vô hiệu hóa cache (cache bust).
  - Do đó, lệnh `RUN pip install` nằm sau bắt buộc phải chạy lại từ đầu, tải và cài đặt lại toàn bộ gói thư viện trong mỗi lần build, làm lãng phí thời gian và băng thông mạng rất lớn.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

- Chuỗi sự kiện:
  1. Kẻ tấn công phát hiện và khai thác một lỗ hổng trong ứng dụng Python (như Command Injection, Remote Code Execution (RCE) qua thư viện deserialization không an toàn).
  2. Vì tiến trình Python trong container đang chạy dưới quyền root (UID 0), kẻ tấn công giành được quyền root bên trong môi trường container.
  3. Từ quyền root container, kẻ tấn công khai thác tiếp một lỗ hổng bảo mật của nhân Linux (kernel exploit) hoặc khai thác các điểm gắn kết mount nhạy cảm (như `docker.sock` hoặc volume bind-mount từ host) để thoát khỏi container (container breakout).
  4. Do kernel Linux quản lý tiến trình bằng UID và UID 0 trong container map thẳng tới UID 0 (root) trên máy host, kẻ tấn công chiếm toàn quyền kiểm soát máy host vật lý/máy ảo.
- Lệnh `USER appuser` cắt đứt chuỗi tấn công ngay tại bước 2: Tiến trình Python chỉ chạy với quyền người dùng không có đặc quyền (non-root, UID thông thường). Kẻ tấn công bị cô lập với quyền hạn tối thiểu, không thể ghi đè các tệp hệ thống trong container, không thể cài đặt mã độc vào thư mục root, và khó có khả năng khai thác các lỗ hổng nhân để thoát ra máy host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

- Người dùng có thể gửi tối đa **20 request** trong 2 giây liên tiếp (gấp đôi hạn mức cho phép).
- Cách đạt được con số đó:
  - Ở giây cuối cùng của phút thứ nhất (ví dụ: `10:00:59`), người dùng gửi nhanh 10 request. Hệ thống tính là 10 request thuộc phút 10, vẫn nằm trong hạn mức 10/phút nên cho qua toàn bộ.
  - Ngay ở giây đầu tiên của phút tiếp theo (`10:01:00`), bộ đếm theo phút đồng hồ bị reset về 0. Người dùng lập tức gửi tiếp 10 request nữa. Hệ thống tính đây là 10 request của phút 11, vẫn hợp lệ và cho qua.
  - Kết quả: Trong khoảng thời gian chỉ 2 giây (từ `10:00:59` đến `10:01:01`), server phải hứng chịu 20 request. Thuật toán sliding window khắc phục điều này bằng cách luôn tính tổng số request trong đúng 60 giây trượt lùi từ thời điểm hiện tại.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

- Điểm khác nhau:
  - **Rate Limit** giới hạn số lượng request trong một khoảng thời gian ngắn (ví dụ: 10 request/phút) để ngăn chặn spam, tấn công DoS và bảo vệ tính sẵn sàng của hệ thống.
  - **Cost Guard** giới hạn tổng chi phí / lượng token tích lũy trong một chu kỳ dài (ví dụ: $10.0/tháng) nhằm bảo vệ ngân sách tài chính khỏi các câu hỏi tiêu tốn nhiều tài nguyên token.
- Tình huống Rate Limit cho qua nhưng Cost Guard chặn:
  - Một user chỉ gửi 1 request duy nhất trong ngày (tần suất cực thấp, Rate Limit chắc chắn cho qua). Tuy nhiên, câu hỏi chứa prompt cực dài kèm tài liệu lớn làm phát sinh chi phí vượt ngân sách tháng còn lại của user, hoặc user đã dùng hết $10.0 trước đó $\rightarrow$ Cost Guard phát hiện và chặn với mã lỗi `402 Payment Required`.
- Tình huống Cost Guard cho qua nhưng Rate Limit chặn:
  - Một user mới toanh chưa tiêu đồng nào trong ngân sách $10.0. User này gửi 15 request liên tiếp trong vòng 5 giây, mỗi request chỉ hỏi một từ đơn giản như "Hi" (tốn rất ít token, chi phí chỉ vài microcent). Cost Guard thấy ngân sách còn dồi dào, nhưng Rate Limit phát hiện 15 request vượt quá 10 req/phút $\rightarrow$ Rate Limit chặn từ request thứ 11 với mã `429 Too Many Requests`.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự các sự kiện xảy ra:
1. Redis gặp sự cố mạng hoặc khởi động lại, mất kết nối trong 30 giây.
2. Endpoint gộp chung (được orchestrator dùng làm liveness probe) kiểm tra Redis và thấy thất bại $\rightarrow$ trả về mã lỗi 503.
3. Orchestrator (Docker/Kubernetes) nhận thấy liveness probe thất bại liên tục nên kết luận rằng tiến trình container bị treo/chết.
4. Orchestrator lập tức ra lệnh kill và restart đồng loạt cả 3 container agent.
5. Khi 3 container mới khởi động lại, chúng lại kiểm tra kết nối Redis ngay lập tức. Vì Redis vẫn chưa hồi phục trong 30 giây này, probe lại thất bại $\rightarrow$ orchestrator lại tiếp tục kill và restart chúng (vòng lặp CrashLoopBackOff).
6. Tải restart liên tục khiến máy host bị nghẽn tài nguyên CPU/RAM. Thay vì chỉ tạm dừng nhận traffic và tự động khôi phục êm đẹp khi Redis sống lại (nhiệm vụ của readiness probe), việc restart làm mất kết nối dở dang của người dùng và làm sụp đổ toàn bộ cụm dịch vụ (cascading failure).

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

- Khi dùng Redis (Stateless):
  - Dữ liệu lịch sử hội thoại nằm tập trung trên Redis. Dù load balancer điều phối request của cùng một user lần lượt vào container agent-1, agent-2 hay agent-3, cả 3 instance đều truy xuất cùng một danh sách trên Redis. Vì vậy `history_length` tăng đều đặn và nhất quán: 0 $\rightarrow$ 2 $\rightarrow$ 4 $\rightarrow$ 6...
- Nếu lưu trong dict Python (Stateful):
  - Mỗi container có một vùng nhớ RAM độc lập. Khi các request liên tiếp được load balancer phân phối xoay vòng (round-robin) qua 3 container:
    - Request 1 vào container A: `history_length = 0` (container A ghi nhận 2 tin nhắn vào RAM riêng).
    - Request 2 vào container B: `history_length = 0` (RAM của container B chưa có gì).
    - Request 3 vào container C: `history_length = 0` (RAM của container C chưa có gì).
    - Request 4 quay lại container A: `history_length = 2`.
  - Người dùng sẽ thấy `history_length` nhảy bất thường và chatbot liên tục bị "mất trí nhớ", không thể duy trì ngữ cảnh trao đổi liền mạch.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

- **Lỗi gặp phải:** Endpoint `/ready` trả về mã lỗi `503 Service Unavailable` kèm payload `{"status": "not ready", "redis": false}` sau khi vừa triển khai service `ai-agent-cloud` lên Railway.
- **Cách tìm nguyên nhân:**
  - Mở Railway Dashboard kiểm tra tab Variables và log của container.
  - Nhận thấy service ban đầu chưa có biến môi trường `REDIS_URL`, hoặc mặc định biến trỏ tới `redis://localhost:6379/0`. Trong môi trường container trên cloud, `localhost` trỏ vào chính container agent chứ không thể kết nối sang service Redis khác.
- **Cách khắc phục:**
  - Dùng Railway CLI thêm database Redis add-on: `railway add --database redis`.
  - Cấu hình biến môi trường trên service `ai-agent-cloud`: `REDIS_URL=${{Redis.REDIS_URL}}`. Railway tự động phân giải biến này thành URL kết nối nội bộ có thông tin xác thực (`redis://default:<password>@redis.railway.internal:6379`).
  - Service tự động kích hoạt deploy lại và endpoint `/ready` lập tức trả về `200 OK {"status": "ready", "redis": true}`.
