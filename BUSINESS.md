# Hotel8:ePOS — Business Requirements & Functionality

> Audience: product owners, business analysts, and anyone evaluating what
> Hotel8:ePOS **does for the business**. For architecture read `README.md`;
> for wire-level detail read `DESIGN.md`.

## 1. Business Purpose

- Run every food-and-beverage revenue center (restaurants, bars, room
  service, banquet) on one unified point-of-sale terminal.
- Post guest charges straight into the PMS folio (room charge), eliminating
  manual reconciliation between restaurant and front-desk systems.
- Protect revenue with manager-gated voids, comps, and discounts, and
  end-of-day reporting that closes the day with cash and card totals.
- Keep menu and pricing changes instant across all terminals through the
  central POS service (86'ing, price updates).

## 2. Business Scope (What the Service Provides)

| Capability | Provided by ePOS |
|---|---|
| Outlet dashboard (daily sales at a glance) | ✅ |
| Check lifecycle: open, add items, void items, transfer, split | ✅ |
| Order entry: categories, items, modifiers, special instructions | ✅ |
| Payment: cash, card (Bill8 capture), room charge, close | ✅ |
| Table management: floor plan, status changes, seat | ✅ |
| Menu administration: browse, 86-toggle availability | ✅ |
| Reporting: shifts, typed reports, daily close | ✅ |
| Full menu item/price/modifier-group CRUD with bulk updates | ❌ service-side/admin surface — not in-app yet |
| Offline order/payment queue | ✅ capture offline (order lines + settlements queue with client idempotency keys) and replay via `POST /v1/offline-sync` on reconnect |
| Kitchen display/printer routing control | ✅ configuration surfaced; thermal printing rides the terminal hardware channel on embedding builds |
| Guest-facing ordering | ❌ delegated — Hotel8:eGuest |
| Hotel reservations/front desk | ❌ delegated — Hotel8:ePMS |

## 3. Business Capabilities

### Sales & service

| Capability | Business rule |
|---|---|
| Order entry | Items are added to an open check with modifiers and (optional) seat assignment; the check's financial totals are always server-computed. |
| Check management | Checks can be transferred between tables, split by seat/item/equally, and voided per item with a reason; voiding and splitting are recorded for audit. |
| Table management | Tables carry an operational status (available, occupied, reserved, dirty, out-of-service); seating a party moves the table into the check flow. |
| 86'ing | A sold-out item is toggled unavailable and it takes effect across all terminals immediately. |

### Payments

| Capability | Business rule |
|---|---|
| Payment methods | A check can be settled with cash, card, or room charge; multiple payments can be applied before closing. |
| Card capture | Card charges are processed as Bill8:Payments charges; the terminal never touches card data. |
| Room charge | Room charges verify the guest stay and post directly into the guest's PMS folio. |
| Close | A check closes only when the balance is fully covered; closing produces the shift-report record. |

### Reporting

| Capability | Business rule |
|---|---|
| Dashboard & shift reports | Revenue, payment mix, tips, and discounts are aggregated per outlet per shift/day. |
| Typed reports | Item sales, labor, and end-of-day reports are served by POS in typed report formats for export. |

## 4. Business Events (Outbound)

ePOS is a client; it emits no events. The staff actions trigger events **in
Hotel8:POS** (see `services/pos/DESIGN.md`), consumed by reporting and the
PMS/loyalty integrations:

| Business moment | Event family (emitted by POS) |
|---|---|
| Order item added / voided | POS order events |
| Payment received / check closed | POS payment events |
| Table status change | POS table events |
| Item 86'd | POS menu events |

**Inbound:** none.

## 5. Business Rules & Invariants

1. All terminal traffic goes through the BFF; the app cannot reach POS, PMS,
   or Payments directly.
2. Money figures displayed are computed by the POS service; the terminal
   never treats local arithmetic as authoritative.
3. Voids, comps, and discounts are gated by role scopes server-side — the UI
   cannot bypass a manager approval.
4. Card data never enters the terminal; card settlement is a Bill8 charge
   outcome.
5. A check closes only against a fully covered balance.
6. 86-toggles take effect on every terminal immediately (central menu
   service, no terminal-local menu override).
7. Room charges always post to the folio through PMS — the terminal cannot
   write to a folio table.

## 6. Target-User Roles & Use Cases

| Persona | What they do with ePOS |
|---|---|
| Server | Starts and maintains checks, enters orders, takes payment, manages own tables. |
| Bartender | Runs bar tabs (open checks without table), quick order entry. |
| Shift manager | Handles voids/comps/discounts within approval limits, reviews shift reports. |
| General manager | 86's items, runs daily close, monitors revenue and payment mix. |
| Administrator | (Config surface) revenue centers, tax groups, printer groups — currently on the service/admin side. |

## 7. KPIs / Success Criteria

- **Check throughput** — time from order entry to payment close per center.
- **Payment mix integrity** — zero discrepancies between POS payment rows and
  Bill8 charges / PMS folio postings at daily close.
- **Void/comp rates** within management tolerance, all fully audit-attributed.
- **Menu freshness** — 86 or price changes visible on all terminals within
  seconds.
- **Uptime at peak** — the terminal is usable through every dinner service;
  failures degrade to a visible error, never a silently lost order.

## 8. Dependencies & Reliance on Other Services

| Reliance | For |
|---|---|
| Hotel8:POS | Checks, orders, menu, tables, payments, reports (all domain truth) |
| Sentin8:BFF | Transport, staff session, tenant resolution |
| Sentin8:Auth (staff env) | Staff identity + role scopes (via BFF) |
| Bill8:Payments | Card capture (via BFF) |
| Hotel8:PMS | Room-charge posting and guest verification (via BFF) |
| Sentin8:App | Listing, runtime context, DCR bootstrap |

## 9. Acceptance Criteria

1. A server can open a check, add items with modifiers, and close it with a
   mixed payment — end to end through the terminal.
2. A void item requires a reason and is visible in check detail afterward.
3. A room charge appears in the guest's folio in PMS immediately after
   payment.
4. An 86'd item cannot be ordered on any terminal from that moment.
5. A shift report reflects all checks closed during the shift, including
   split payments.
6. Payment amounts in POS match Bill8 charges and folio postings with zero
   manual correction at day close.

## 10. Open Business Questions

- Which roles get manager-approval rights for comp/discount thresholds, and
  are thresholds configured per revenue center?
- Should menu item/price CRUD live in the terminal for managers, or stay on
  the web admin surface?
- When does the offline pattern land, and does room charge work offline
  (folio is inherently online)?

---

**Design attribution:** hotel8:epos and its underlying concepts were designed by Hamid Jahanzad <Hamid@Jahanzad.com>.
