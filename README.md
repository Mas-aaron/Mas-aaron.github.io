# Food Delivery Platform

This project is a comprehensive food delivery platform featuring a backend API and three separate frontend applications for customers, restaurants, and delivery riders.

## System Architecture

The platform is built with a modern stack, consisting of a Django backend and Flutter frontends.

*   __Backend__: A robust API built with Django and Django REST Framework. It handles business logic, user authentication, order processing, and real-time communication via WebSockets using Django Channels.
*   __Frontend Apps__: Three distinct cross-platform mobile applications built with Flutter:
    *   `food_delivery_app`: Allows customers to browse restaurants, place orders, and track deliveries.
    *   `restaurant_dashboard_new`: A dashboard for restaurant owners to manage their menu, view incoming orders, and track analytics.
    *   `rider_app`: An application for delivery riders to view and accept delivery jobs.

## Project Structure

```
/
├── backend/                  # Django REST Framework backend
├── frontend/
│   ├── food_delivery_app/      # Flutter app for customers
│   └── restaurant_dashboard_new/ # Flutter app for restaurants
├── rider_app/                # Flutter app for delivery riders
├── railway.json              # Deployment configuration for Railway
└── ...                       # Other configuration files
```

## Getting Started

### Backend Setup

1.  __Navigate to the backend directory__:
    ```sh
    cd backend
    ```

2.  __Install dependencies__ using Poetry:
    ```sh
    poetry install
    ```

3.  __Run the development server__:
    For stable execution on Windows, use the following command in PowerShell:
    ```powershell
    $env:DEBUG='True'; poetry run daphne food_delivery.asgi:application --bind 0.0.0.0 --port 8000
    ```
    The API will be available at `http://0.0.0.0:8000`.

### Frontend Setup

The setup process is similar for all three Flutter applications (customer, restaurant, and rider).

1.  __Navigate to the app directory__, for example:
    ```sh
    cd frontend/food_delivery_app
    ```

2.  __Configure the Backend URL__:
    Before running the app, ensure it's pointing to your local backend server. Update the IP address in the `constants.dart` file for each respective app:
    *   Customer App: `frontend/food_delivery_app/lib/constants.dart`
    *   Restaurant App: `frontend/restaurant_dashboard_new/lib/constants.dart`
    *   Rider App: `rider_app/lib/constants.dart`

    Set the `baseUrl` to your machine's local IP address (e.g., `http://10.5.55.117:8000/api`).

3.  __Install dependencies__:
    ```sh
    flutter pub get
    ```

4.  __Run the application__:
    ```sh
    flutter run
    ```

---

## Frontend Applications

This section provides an overview of the three frontend applications.

### 1. Customer App (`food_delivery_app`)

This application allows users to browse restaurants, view menus, add items to a cart, and place orders.

**Architecture:**

The app's `lib` directory is organized as follows:

-   `screens/`: Contains the UI for each screen in the app (e.g., home, restaurant details, cart, order tracking).
-   `services/`: Handles business logic and communication with the backend API (e.g., `ApiService`, `AuthService`).
-   `providers/`: Manages state using the Provider package (e.g., `CartProvider`, `UserProvider`).
-   `models/`: Defines the data structures used throughout the app (e.g., `Restaurant`, `MenuItem`, `Order`).
-   `widgets/`: Stores reusable UI components shared across multiple screens.
-   `constants.dart`: A centralized file for application-wide constants, such as the backend API URL.

### 2. Restaurant Dashboard App (`restaurant_dashboard_new`)

This app serves as a management tool for restaurant owners. It allows them to view incoming orders in real-time, manage their menu and item availability, and view sales analytics.

**Architecture:**

Similar to the customer app, the `lib` directory is structured for clarity and maintainability:

-   `screens/`: Contains the UI for the dashboard's features (e.g., `HomeScreen` for live orders, `MenuScreen`, `AnalyticsScreen`).
-   `services/`: Handles backend communication, including real-time updates via WebSockets for new orders (`WebSocketService`).
-   `models/`: Defines data structures specific to the restaurant's needs (e.g., `Order`, `MenuItem`, `SalesData`).
-   `providers/`: Manages state for the dashboard.
-   `widgets/`: Contains reusable UI components for the dashboard interface.

### 3. Rider App (`rider_app`)

This application is designed for delivery riders. It allows them to see available delivery jobs, accept jobs, view order details and delivery locations, and update the delivery status.

**Architecture:**

The `lib` directory follows the same structure as the other applications:

-   `screens/`: Contains the UI for the rider's workflow (e.g., `AvailableJobsScreen`, `JobDetailsScreen`, `MapViewScreen`).
-   `services/`: Manages communication with the backend to fetch job information and update order statuses.
-   `models/`: Defines data structures for jobs and delivery details.
-   `widgets/`: Stores reusable UI components for the rider interface.

---

## API Documentation

**Base URL:** `/api`

### Authentication

Authentication is token-based. After registering or logging in, a token is provided. This token must be included in the `Authorization` header for all protected endpoints.

**Header Format:** `Authorization: Token <your_token_here>`

#### 1. Register User

- **Endpoint:** `POST /api/register/`
- **Description:** Creates a new user and a corresponding shopping cart.
- **Permissions:** `AllowAny`
- **Request Body:**
  ```json
  {
    "username": "newuser",
    "password": "password123"
  }
  ```
- **Response:**
  ```json
  {
    "id": 1,
    "username": "newuser"
  }
  ```

#### 2. Login (Get Auth Token)

- **Endpoint:** `POST /api/login/`
- **Description:** Obtains an authentication token for a user.
- **Permissions:** `AllowAny`
- **Request Body:**
  ```json
  {
    "username": "newuser",
    "password": "password123"
  }
  ```
- **Response:**
  ```json
  {
    "token": "your_auth_token"
  }
  ```

### Restaurants & Menus

#### 1. List Restaurants

- **Endpoint:** `GET /api/restaurants/`
- **Description:** Retrieves a list of all available restaurants.
- **Permissions:** `AllowAny`

#### 2. Get Restaurant Menu

- **Endpoint:** `GET /api/restaurants/<restaurant_pk>/menu/`
- **Description:** Retrieves the menu for a specific restaurant, organized by categories.
- **Permissions:** `AllowAny`

### Shopping Cart

These endpoints require authentication.

#### 1. Get Cart

- **Endpoint:** `GET /api/cart/`
- **Description:** Retrieves the current user's shopping cart.
- **Permissions:** `IsAuthenticated`

#### 2. List Cart Items

- **Endpoint:** `GET /api/cart-items/`
- **Description:** Lists all items in the user's cart.
- **Permissions:** `IsAuthenticated`

#### 3. Add/Update Cart Item

- **Endpoint:** `POST /api/cart-items/`
- **Description:** Adds a new item to the cart or increases the quantity if the item already exists.
- **Permissions:** `IsAuthenticated`
- **Request Body:**
  ```json
  {
    "menu_item_id": 1,
    "quantity": 1
  }
  ```

#### 4. Update Cart Item Quantity

- **Endpoint:** `PATCH /api/cart-items/<item_id>/`
- **Description:** Updates the quantity of a specific item in the cart.
- **Permissions:** `IsAuthenticated`
- **Request Body:**
  ```json
  {
    "quantity": 3
  }
  ```

#### 5. Delete Cart Item

- **Endpoint:** `DELETE /api/cart-items/<item_id>/`
- **Description:** Removes an item from the cart.
- **Permissions:** `IsAuthenticated`

### Orders

These endpoints require authentication.

#### 1. List Orders

- **Endpoint:** `GET /api/orders/`
- **Description:** Retrieves a list of the current user's past and current orders.
- **Permissions:** `IsAuthenticated`

#### 2. Place Order

- **Endpoint:** `POST /api/orders/`
- **Description:** Creates a new order from the user's current cart items and clears the cart.
- **Permissions:** `IsAuthenticated`
- **Request Body:**
  ```json
  {
    "delivery_address": "123 Main St, Anytown, USA"
  }
  ```
