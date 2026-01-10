# Kassorama

Kassorama is a Point of Sale (POS) and inventory management system built with Ruby on Rails 7. It features a modern interface using Tailwind CSS and integrates with Bexio for accounting.

## Prerequisites

*   **Ruby**: 3.2.2
*   **Bundler**: `gem install bundler`
*   **SQLite3**: Used for the database.

## Installation

1.  **Clone the repository:**
    ```bash
    git clone <repository_url>
    cd kassorama
    ```

2.  **Install dependencies:**
    ```bash
    bundle install
    ```

3.  **Setup the database:**
    ```bash
    rails db:create
    rails db:migrate
    rails db:seed # Optional: only if you need initial seed data
    ```

## Development

To start the development server with Tailwind CSS watching for changes (recommended):

```bash
./bin/dev
```

Or run the rails server directly (CSS won't auto-compile/watch):

```bash
rails server
```

The application will be available at `http://localhost:3000`.

## Features

### Bexio Integration
Kassorama integrates with Bexio for accounting purposes.
*   **Settings**: Go to `Accounting -> Settings` to configure your Bexio API Client ID and Secret.
*   **Authentication**: Authenticate via OAuth2 to connect your Bexio account.
*   **Import Accounts**: Import your chart of accounts directly from Bexio.
*   **Export Entries**: Export daily turnover or manual entries directly to Bexio's GNB (General Ledger).

### Point of Sale (POS)
*   **Cash Register**: Manage sales, handle cash and voucher payments.
*   **Vouchers**: Issue and redeem vouchers.
*   **Discounts**: Apply discounts to order items.

### Inventory & Articles
*   **Articles**: Manage products, pricing (fixed or free price), and tax codes.
*   **Inventory**: Track stock levels and locations.
*   **PDF Reports**: Generate inventory reports using Prawn.

## Testing

Run the test suite with:

```bash
rails test
```
