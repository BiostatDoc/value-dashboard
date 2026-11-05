# Spec: Value Dashboard (rebuild)

## Users
- Physicians / surgeons. There are no other user groups.
- What they use it for:
  - Comparing their cost, outcomes, and volume with peers.
  - Understanding the cost and value of their cases.
  - Tracking patient outcomes.
  - Watching their own case volume and trends over time.

## Screens
The dashboard has four tabs, plus one shared set of filters.

1. **Volume**
   - Line chart, one point per month: the selected surgeon's case count.
2. **Cost / Value**
   - Line chart, one point per month: average cost per case.
   - Line chart with two lines, one point per month: average revenue per case and average
     margin per case.
3. **Outcomes**
   - Line chart, one point per month: average length of stay.
   - Line chart, one point per month: mortality rate.
4. **Peer comparison**
   - Table with one row per surgeon. All surgeons are listed by name.
   - Columns: surgeon, cases, avg cost per case, avg revenue per case, avg margin per case,
     avg length of stay, mortality rate.
   - Each row covers the date range chosen in the filters.
   - Click any column header to sort.

Every tab shows the **data-as-of date**: the latest surgery month loaded. This is new in this
version.

### Filters
One set of filters is shared by all four tabs.
- **Date range** (by surgery date). Defaults to the last 12 months.
- **Surgeon**: one surgeon at a time. Any user can pick any surgeon. Defaults to the logged-in
  surgeon. The Peer comparison table ignores this filter and always lists every surgeon.
- **Procedure type**: multi-select. Defaults to all.

## Metrics
### Case
- One row in the clinical file is one case.
- Each case is credited only to its primary surgeon. A co-surgeon gets no credit.
- A case belongs to the month of its surgery date.
- Case count = number of cases in the month (or the filter period).

### Average cost per case
- Cost = the finance file's total cost for the case (direct + indirect).
- Avg cost per case = sum of cost / number of cases.

### Average revenue and margin per case
- Revenue = the payment actually received for the case.
- Margin = revenue − cost, per case.
- Avg revenue per case = sum of revenue / number of cases.
- Avg margin per case = sum of margin / number of cases.

### Average length of stay
- LOS = discharge date − admission date, in whole days. A same-day case is 0. Taken from the
  clinical file's length-of-stay column.
- Avg LOS = mean LOS over the cases in the month (or the filter period).

### Mortality rate
- Died = the patient died in hospital before discharge (the clinical file's "died" flag).
- Mortality rate = cases where died is true / all cases, shown as a percent.

### Worked example (made-up data)
Dr. A, March, 4 cases:

| Case | Cost   | Revenue | LOS | Died |
|------|--------|---------|-----|------|
| 1    | 10,000 | 12,000  | 0   | no   |
| 2    | 20,000 | 18,000  | 3   | no   |
| 3    | 15,000 | 16,000  | 2   | no   |
| 4    | 25,000 | 30,000  | 7   | yes  |

- Cases = 4
- Avg cost = 70,000 / 4 = 17,500
- Avg revenue = 76,000 / 4 = 19,000
- Avg margin = (2,000 − 2,000 + 1,000 + 5,000) / 4 = 1,500
- Avg LOS = 12 / 4 = 3.0 days
- Mortality = 1 / 4 = 25%

## Data
- **Sources:** files exported from the EHR and from the finance system, plus a lookup
  spreadsheet. There are no direct database connections.
- **Files in each monthly drop:**
  1. Clinical file (EHR): one row per case. Case ID, primary surgeon, procedure, surgery date,
     admission date, discharge date, length of stay, died.
  2. Finance file: case ID, total cost, revenue. Joined to the clinical file on case ID.
  3. Lookup spreadsheet: surgeon ID → name and SSO email; procedure code → procedure group.
- **Refresh:** monthly and manual. Someone exports the files and drops them in a shared folder,
  and the app loads them from there.
- Each drop adds only one new month. Earlier months are kept.
- Each export covers surgeries from 2 or more months ago, so stays and payments are mostly
  complete. The newest month shown is about 2 months old.
- **Size:** under about 50 surgeons and 10,000 cases a year.

### Loading and checks
- Columns are matched by name, not by position.
- Rows that are identical in every column are kept once.
- A drop **fails** if any of these is true:
  - A required column is missing.
  - A case ID appears more than once with different values.
  - A clinical case has no matching row in the finance file.
  - A surgeon or procedure code is not in the lookup sheet.
  - A surgery, admission, or discharge date can't be read, or discharge is before admission.
- When a drop fails, nothing from it is loaded and the dashboard keeps showing its previous data.
  A plain-text or CSV report listing every problem is written next to the dropped files.
- Not checked, by choice: text or blanks in number columns, negative values, a "died" flag that
  isn't yes/no, and surgery dates outside the expected month.

## Access
- Login: hospital single sign-on.
- Only surgeons in the lookup spreadsheet (matched by SSO email) can log in. Anyone else is
  refused.
- Everyone who logs in sees all surgeons by name. There is one role and no admin.
- The SSO email links the user to their surgeon ID, which sets the Surgeon filter's default.

## What's broken today, and the fix
- **Case counts are wrong:** the same case ID appears more than once in the clinical file and
  is counted twice. Fix: the duplicate rules under Loading and checks.
- **Loading breaks:** renamed or reordered columns in the export break the dashboard. Fix:
  match columns by name, check required columns, and reject a bad drop with a report.

## Out of scope
- Direct connections to the EHR or finance databases.

## Open questions
- Exact column names and types in each file. Check with whoever does the exports.
- Which SSO provider (e.g. Microsoft Entra, Okta).
- Where on each tab the data-as-of date appears.
- How a drop that repeats an already-loaded month or case should be handled.
- Whether these items are out of scope or future ideas (not discussed): risk adjustment,
  CSV/Excel export, peer lines on charts, small-number warnings, an admin role, and a phone
  layout.
