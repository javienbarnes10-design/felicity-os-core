import cv2, time
url = "http://100.99.242.53:4747/video"
while True:
    cap = cv2.VideoCapture(url)
    if not cap.isOpened():
        time.sleep(1)
        continue
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret: break
        cv2.imwrite("frame.png", frame)
        time.sleep(0.5)
    cap.release()
    time.sleep(1)
