# Food Inventory Management Application

A comprehensive inventory management solution designed for restaurants, hotels, and catering services to efficiently track food items, manage expiry dates, control budgets, and reduce wastage.

## 📖 Project Overview

This application helps large food establishments manage their inventory by:
- **Barcode Scanning**: Quick product entry via barcode scanning
- **Expiry Date Tracking**: Automated alerts for items approaching expiration
- **Budget Management**: Real-time tracking of expenses and budget allocation
- **Wastage Control**: Monitor and reduce food wastage through better inventory management
- **Team Communication**: Built-in chat interface for organizational communication
- **Dashboard Analytics**: Comprehensive reporting on inventory, budget, and wastage

## 🚀 Technologies Used

### Frontend
- **Flutter**: Cross-platform mobile app development
- **Dart**: Programming language for Flutter
- **Android Studio**: IDE for app development and testing

### Backend
- **Python**: Server-side programming language
- **Django**: High-level Python web framework
- **Django REST Framework**: API development

### Database
- **MongoDB**: NoSQL database for flexible data storage

### Development Tools
- **VS Code**: Primary code editor
- **Terminal/Command Line**: Project management and execution
- **Git**: Version control system
## ⚙️ Key Components

### Frontend Components
- **Dashboard Screen**: Overview of inventory status and alerts
- **Barcode Scanner**: Product scanning and entry interface
- **Inventory List**: Complete inventory management view
- **Expiry Alerts**: Notifications for items approaching expiration
- **Budget Tracker**: Financial overview and budget management
- **Chat Interface**: Team communication feature
- **Settings**: App configuration and user preferences

### Backend Components
- **Product Model**: Product information and barcode data
- **Inventory Model**: Stock levels and tracking
- **Expiry Management**: Date tracking and alert system
- **User Authentication**: Secure login and authorization
- **API Endpoints**: RESTful services for mobile app
- **Notification Service**: Push notifications and alerts
- **Chat System**: Real-time messaging functionality

### Screenshots:
![Starting_App](https://github.com/user-attachments/assets/8e839148-67d9-48ce-a08b-1602f150dc57)
![App_Signup](https://github.com/user-attachments/assets/18bb00cd-98e7-442e-b0ae-97cd5b6be753)
![App_Signin](https://github.com/user-attachments/assets/2d369161-e755-407b-8373-b04ddd60d051)
![App_dashboard](https://github.com/user-attachments/assets/3ced6732-03d3-4b4d-b929-aa6c54b13687)
![barcode_scanning](https://github.com/user-attachments/assets/29e53dfb-f7f4-4a55-9aac-40f9ba0b0ad5)
![scanned_item](https://github.com/user-attachments/assets/8bfc8325-a521-46a1-a878-8e750f36de02)
![alerts](https://github.com/user-attachments/assets/89cd8104-beef-47d0-ab09-7a3f5a84bd68)
![teamchat](https://github.com/user-attachments/assets/2d154c5a-d7a8-498d-bc70-d96029364ff2)
![account_manager](https://github.com/user-attachments/assets/72f886b3-685d-4627-b81b-3d7b1c204fcd)


## 🛠️ Installation & Setup

### Prerequisites
- Flutter SDK (latest stable version)
- Python 3.9+
- MongoDB
- Android Studio
- VS Code
- Git

### Backend Setup
1. **Clone the repository**
```bash
   git clone <repository-url>
   cd food-inventory-management


⚡ Getting Started
🔹 Backend Setup

Install dependencies

pip install -r requirements.txt


Configure MongoDB

# Start MongoDB service
# Update database settings in settings.py


Run migrations

python manage.py makemigrations
python manage.py migrate


Create superuser

python manage.py createsuperuser


Start development server

python manage.py runserver

🔹 Frontend Setup

Navigate to frontend:

cd frontend


Install Flutter dependencies:

flutter pub get


Configure API endpoint (update lib/services/api_service.dart):

static const String baseUrl = 'http://localhost:8000/api/';


Run the app:

# For emulator
flutter run

# For specific device
flutter devices
flutter run -d <device-id>

🛠 Running the Project
Development Mode

Start MongoDB

mongod


Run Django backend

cd backend
source venv/bin/activate   # Windows: venv\Scripts\activate
python manage.py runserver


Run Flutter frontend

cd frontend
flutter run

Production Deployment

Backend: Deploy Django app with Heroku, AWS, or DigitalOcean

Database: Use MongoDB Atlas for cloud hosting

Frontend: Build APK/iOS app for distribution

📱 Features
Core Features

✅ Barcode scanning for quick product entry
✅ Automated expiry date alerts
✅ Real-time inventory monitoring
✅ Expense and budget tracking
✅ Wastage reduction analytics
✅ Team chat communication
✅ Dashboard with detailed reports
✅ Multi-user role-based access

Planned Features

🔄 Integration with supplier APIs
🔄 Advanced analytics & forecasting
🔄 Push notifications
🔄 Report generation & export
🔄 Multi-location inventory support

📄 API Documentation
Base URL

http://localhost:8000/api/

Endpoints
GET /products/ → List all products
POST /products/ → Add new product
GET /inventory/ → Get inventory status
POST /inventory/scan/ → Process barcode scan
GET /alerts/ → Get expiry alerts
POST /chat/messages/ → Send chat message

🔧 Configuration
Environment Variables
Create a .env in backend:
DEBUG=True
SECRET_KEY=your-secret-key
DATABASE_URL=mongodb://localhost:27017/inventory_db
ALLOWED_HOSTS=localhost,127.0.0.1

Flutter Config
Update lib/config/app_config.dart:

class AppConfig {
  static const String apiBaseUrl = 'http://localhost:8000/api/';
  static const String appName = 'Inventory Manager';
  static const bool enableDebugMode = true;
}

📊 Database Schema

products → Product info & barcodes
inventory → Current stock levels
users → User accounts & permissions
alerts → Expiry & low-stock notifications
transactions → Inventory movements
messages → Team chat messages
