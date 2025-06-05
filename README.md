# workout_analyzer


## Project Flow

WORKOUT ANALYZER:
lib/
├── main.dart
├── app.dart                          # Root widget and router setup
├── config/
│   └── firebase_options.dart         # Firebase setup file
├── models/
│   └── keypoint_model.dart           # Data model for 33 keypoints
│   └── user_model.dart               # (optional) for auth-based user handling
├── services/
│   ├── firebase_service.dart         # Upload to Firestore + Firebase Storage
│   ├── media_pipe_service.dart       # Call to Python backend API
│   ├── local_db_service.dart         # SQLite helper
│   └── auth_service.dart             # FirebaseAuth functions
├── controllers/
│   ├── camera_controller.dart        # Logic for camera feed
│   ├── capture_controller.dart       # Logic for capturing and saving photo
│   ├── history_controller.dart       # Load saved poses
│   └── auth_controller.dart          # Sign in / sign up logic
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── signup_screen.dart
│   ├── camera/
│   │   └── live_camera_screen.dart   # Live camera feed
│   ├── capture/
│   │   └── photo_capture_screen.dart # Capture photo from camera
│   ├── history/
│   │   └── history_screen.dart       # List saved entries
│   ├── details/
│   │   └── keypoint_detail_screen.dart # View full keypoints JSON
│   └── home_screen.dart              # Navigation hub
├── widgets/
│   └── image_thumbnail.dart          # Reusable thumbnail widget
│   └── primary_button.dart           # Reusable button
├── utils/
│   ├── constants.dart                # Firebase keys, URLs, styles
│   └── logger.dart                   # Centralized error logger


MEDIAPIPE SERVICE:
backend/
├── app.py                         # Flask API
├── pose_estimation.py            # MediaPipe Pose logic
├── utils.py                      # Helper: image decode, response format
├── requirements.txt              # Required libraries
└── static/
└── uploads/                  # Temp store images

## Navigation Flow

Login/Signup → Home Screen
               ↙         ↘
    Live Camera Feed   Photo Capture (Saves to history)
                            ↓
                       History Screen → Keypoint JSON Viewer

## Getting Started
