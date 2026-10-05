---
name: money
description: the user's money check-in from Era. Shows spent vs monthly limits, bills, savings and anything odd. Use when the user says "/money", "how am I doing for money", "am I over budget", "what have I spent", "money check", "weekly money brief". Do NOT use to move money, change billing, connect or disconnect banks, or for ParentCo work expenses (that is parentco-expenses).
---

# Money

Era (era.app, MCP server `era`) is the user's money system. It replaced his spreadsheet.
This skill is read-only. Never call any Era billing, connection, disconnect or
account-management tool from here.

## Steps

1. Load limits: `knowledge__get_financial_context_and_overview`. Read the facts with
   slugs `monthly-budget-limit` (instances shopping, eating-in-takeaway, extras,
   transport), `monthly-savings-target` (the savings app, kids-savings) and
   `monthly-fixed-bills-total`. If any are missing, say which and carry on with the rest.
2. Spending: `insights__analyze_spending` with `period: this_month`,
   `group_by: category`, `top_n: 30`. Also run `last_month` if it is before the 5th.
3. Map Era categories onto his budget lines:

   | His line | Era categories |
   |---|---|
   | Shopping | Shopping and gear |
   | Eating in/Takeaway | Dining out, Coffee and snacks, Groceries |
   | Transport | Public transit, Ride shares, Vehicle expenses |
   | Extras | Entertainment and subscriptions, Health and fitness, Travel and vacation, Gifts given and donations, Cash checks and misc, Home maintenance and improvement, Education |
   | Bills | Mortgage and home equity, Utilities, Insurance, Taxes and bank fees, Childcare, Pets, Healthcare and pharmacy, Student loans and personal debt |
   | Savings | Savings goals (the savings app rule), Stocks and investments, Emergency fund |
   | Ignore | Transfers and card payments (credit card payoffs, double counting), Income |

   Any Era category not in the table goes under Extras and gets named in the reply.
4. Pace: compare spent against (limit x day of month / days in month). Over pace = flag.
5. Oddities (max 3): new merchants over £100, anything in "Cash, checks, and misc"
   over £50 (use `transactions__search_transactions` with that category key), and
   any `warnings` array the Era tools returned (for example a bank needing reconnecting).
6. Balances: `accounts__list_financial_accounts`. Current account and credit card owed.

## Reply shape

One table, then at most 3 lines. No preamble.

| Line | Spent | Limit | Left | Pace |
|---|---|---|---|---|

Then: balances in one line, oddities (max 3), one suggested action if something is over.
Plain English, pounds rounded to the nearest pound, no category keys or tool names.

## Known limits

- Free Era plan: only about the last 20 days of transactions can be listed one by one.
  Category totals still cover the whole month.
- Only the bank current account and credit card are connected. the savings app is savings and is
  deliberately not connected. the user does not use Amex.
- Limits come from the "October 26" tab of his old spreadsheet. If he changes a limit,
  update the matching fact with `knowledge__remember` (same slug and instance_id).
