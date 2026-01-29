# Transaction Direction & Party Tracking

## Overview
Enhanced the receipt classification system to track transaction direction (credit/debit/purchase/third-party) and all parties involved (sender, recipient, merchant) for comprehensive financial tracking.

## New Fields

### Database Schema (v2)
- `sender_name` (TEXT) - Who sent the money
- `recipient_name` (TEXT) - Who received the money
- `transaction_type` (TEXT) - Type of transaction: 'credit', 'debit', 'purchase', or 'third_party'

### LLM Extraction
The AI now extracts:
1. **merchant_name** - For purchases: store name. For transfers: bank/service name
2. **sender_name** - Who sent the money (null for purchases)
3. **recipient_name** - Who received the money (null for purchases)
4. **transaction_type** - Transaction classification:
   - `credit` - User received money
   - `debit` - User sent money
   - `purchase` - Retail transaction
   - `third_party` - Neither user sent nor received
5. **total_amount** - Always positive number
6. **transaction_date** - ISO8601 format
7. **document_type** - pos_receipt, digital_receipt, invoice, bank_statement, transfer_receipt, other
8. **category** - e.g., Food, Transfer, Shopping, etc.

## Example Scenarios

### Scenario 1: You Received Money (Credit)

#### Input (OCR Text):
```
Transaction Details
04 February, 2025
From: Faizyab (288750501)
To: Waqad (143196505100380)
Bank: MCB
Status: Paid
Amount Debited: PKR 42,000
```

#### Output (Structured Data):
```json
{
  "merchant_name": "UBL Digital",
  "sender_name": "Faizyab",
  "recipient_name": "Waqad",
  "transaction_type": "credit",
  "total_amount": 42000,
  "transaction_date": "2025-02-04",
  "document_type": "transfer_receipt",
  "category": "Transfer"
}
```

#### UI Display:
```
┌─────────────────────────────────┐
│  Receipt Details:               │
├─────────────────────────────────┤
│  🏪 Merchant                    │
│     UBL Digital                 │
│                                 │
│  👤 From                        │
│     Faizyab                     │
│                                 │
│  👥 To                          │
│     Waqad                       │
│                                 │
│  💵 Received                    │
│     $42,000.00                  │
│                                 │
│  📅 Date                        │
│     2025-02-04                  │
│                                 │
│  📂 Category                    │
│     Transfer                    │
└─────────────────────────────────┘
```

### Scenario 2: You Sent Money (Debit)

#### Output:
```json
{
  "merchant_name": "Bank XYZ",
  "sender_name": "Waqad",
  "recipient_name": "Electricity Company",
  "transaction_type": "debit",
  "total_amount": 5000,
  "transaction_date": "2025-02-05",
  "document_type": "transfer_receipt",
  "category": "Utilities"
}
```

#### UI Display:
```
┌─────────────────────────────────┐
│  👤 From                        │
│     Waqad                       │
│                                 │
│  👥 To                          │
│     Electricity Company         │
│                                 │
│  💵 Sent                        │
│     $5,000.00                   │
└─────────────────────────────────┘
```

### Scenario 3: Third-Party Transaction

#### Input:
```
Brother sent money to his friend
From: Ali
To: Ahmed
Amount: 10,000 PKR
```

#### Output:
```json
{
  "merchant_name": "Bank ABC",
  "sender_name": "Ali",
  "recipient_name": "Ahmed",
  "transaction_type": "third_party",
  "total_amount": 10000,
  "document_type": "transfer_receipt",
  "category": "Transfer"
}
```

#### UI Display:
```
┌─────────────────────────────────┐
│  👤 From                        │
│     Ali                         │
│                                 │
│  👥 To                          │
│     Ahmed                       │
│                                 │
│  💵 Amount                      │
│     $10,000.00                  │
└─────────────────────────────────┘
```

### Scenario 4: Retail Purchase

#### Output:
```json
{
  "merchant_name": "Starbucks",
  "sender_name": null,
  "recipient_name": null,
  "transaction_type": "purchase",
  "total_amount": 5.50,
  "document_type": "pos_receipt",
  "category": "Food & Beverage"
}
```

#### UI Display:
```
┌─────────────────────────────────┐
│  🏪 Merchant                    │
│     Starbucks                   │
│                                 │
│  💵 Amount                      │
│     $5.50                       │
│                                 │
│  📂 Category                    │
│     Food & Beverage             │
└─────────────────────────────────┘
```

## Transaction Type Logic

### Credit (Money Received)
- **sender_name** = Person/entity who sent
- **recipient_name** = You (the user)
- **Amount Label:** "Received"
- **Use Case:** Payments received, refunds, salary

### Debit (Money Sent)
- **sender_name** = You (the user)
- **recipient_name** = Person/entity who received
- **Amount Label:** "Sent"
- **Use Case:** Bill payments, transfers out, purchases via bank

### Purchase (Retail)
- **sender_name** = null
- **recipient_name** = null
- **merchant_name** = Store/business
- **Amount Label:** "Amount"
- **Use Case:** POS receipts, online shopping, restaurant bills

### Third-Party (Neither You)
- **sender_name** = Other person who sent
- **recipient_name** = Other person who received
- **Amount Label:** "Amount"
- **Use Case:** Screenshots of others' transactions, family member transactions

## Database Migration

Database automatically migrates from v1 to v2 by adding:
```sql
ALTER TABLE processed_images ADD COLUMN sender_name TEXT;
ALTER TABLE processed_images ADD COLUMN recipient_name TEXT;
ALTER TABLE processed_images ADD COLUMN transaction_type TEXT;
```

## Search & Filter Benefits

With both sender and recipient tracked, you can:
1. ✅ Search for all money received from "Faizyab"
2. ✅ Search for all payments sent to "Electricity Company"
3. ✅ Track third-party transactions (family members)
4. ✅ Distinguish between "I paid Starbucks" vs "Starbucks refunded me"
5. ✅ Generate accurate financial reports (income vs expenses)

## Model Selection

**Recommended:** `google/gemini-2.0-flash-lite-preview-02-05:free`

**Why not DeepSeek R1?**
- DeepSeek R1 is a reasoning model (slower, more verbose)
- Receipt extraction is straightforward - doesn't need chain-of-thought
- Gemini Flash Lite is faster and better at structured JSON output

