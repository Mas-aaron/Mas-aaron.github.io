# Food Delivery App API Documentation

This document provides details on the API endpoints for the Food Delivery App.

**Base URL:** `/api`

---

## Authentication

Authentication is token-based. After registering or logging in, a token is provided. This token must be included in the `Authorization` header for all protected endpoints.

**Header Format:** `Authorization: Token <your_token_here>`

### 1. Register User

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

### 2. Login (Get Auth Token)

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

---

## Restaurants & Menus

### 1. List Restaurants

- **Endpoint:** `GET /api/restaurants/`
- **Description:** Retrieves a list of all available restaurants.
- **Permissions:** `AllowAny`

### 2. Get Restaurant Menu

- **Endpoint:** `GET /api/restaurants/<restaurant_pk>/menu/`
- **Description:** Retrieves the menu for a specific restaurant, organized by categories.
- **Permissions:** `AllowAny`

---

## Shopping Cart

These endpoints require authentication.

### 1. Get Cart

- **Endpoint:** `GET /api/cart/`
- **Description:** Retrieves the current user's shopping cart.
- **Permissions:** `IsAuthenticated`

### 2. List Cart Items

- **Endpoint:** `GET /api/cart-items/`
- **Description:** Lists all items in the user's cart.
- **Permissions:** `IsAuthenticated`

### 3. Add/Update Cart Item

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

### 4. Update Cart Item Quantity

- **Endpoint:** `PATCH /api/cart-items/<item_id>/`
- **Description:** Updates the quantity of a specific item in the cart.
- **Permissions:** `IsAuthenticated`
- **Request Body:**
  ```json
  {
    "quantity": 3
  }
  ```

### 5. Delete Cart Item

- **Endpoint:** `DELETE /api/cart-items/<item_id>/`
- **Description:** Removes an item from the cart.
- **Permissions:** `IsAuthenticated`

---

## Orders

These endpoints require authentication.

### 1. List Orders

- **Endpoint:** `GET /api/orders/`
- **Description:** Retrieves a list of the current user's past and current orders.
- **Permissions:** `IsAuthenticated`

### 2. Place Order

- **Endpoint:** `POST /api/orders/`
- **Description:** Creates a new order from the user's current cart items and clears the cart.
- **Permissions:** `IsAuthenticated`
- **Request Body:**
  ```json
  {
    "delivery_address": "123 Main St, Anytown, USA"
  }
  ```
