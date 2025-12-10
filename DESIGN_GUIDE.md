# Contri Pro - Visual & UI Design Guide

## 🎨 Design System Overview

### Color Palette
```
Primary:        Theme.colorScheme.primary
Secondary:      Theme.colorScheme.secondary
Success:        Colors.green.shade700
Warning:        Colors.orange.shade700
Neutral:        Colors.grey.shade600
Background:     Colors.white / Colors.grey.shade50
```

### Typography Stack
```
Headline (SliverAppBar):  GoogleFonts.lato(fontSize: 18, fontWeight: w700)
Title (Settlement):        GoogleFonts.lato(fontSize: 14, fontWeight: w700)
Body (Description):        GoogleFonts.lato(fontSize: 14, fontWeight: w600)
Subtitle (Payer):          GoogleFonts.lato(fontSize: 12, fontWeight: w500)
Caption (Status):          GoogleFonts.lato(fontSize: 12, fontWeight: w600)
Micro (Label):             GoogleFonts.lato(fontSize: 12, fontWeight: w600)
```

### Spacing Scale
```
4px  → micro gaps
8px  → small gaps
12px → standard padding
16px → section padding
20px → large spacing
80px → FAB spacing (bottom)
```

---

## 📐 GroupDetailsScreen Layout Specifications

### Header (Expandable to 280dp)

#### Collapsed State (56dp)
```
┌────────────────────────────────────────────┐
│ [Group Name Title]          [Share] [Info] │
└────────────────────────────────────────────┘
  Default AppBar height
```

#### Expanded State (280dp total)
```
┌────────────────────────────────────────────────────┐
│                                    [Share] [Info]  │
│  [Gradient Background]                            │
│  ┌────────────────────────────────────────────┐   │
│  │                                            │   │
│  │  Your Balance                              │   │
│  │  ₹1,234.50                                 │   │
│  │  [Green/Orange/Grey]                       │   │
│  │  You will get back / You owe / Settled up  │   │
│  │                                            │   │
│  │         [Settle Up Button - White]         │   │
│  │                                            │   │
│  └────────────────────────────────────────────┘   │
│  [Group Name Title - Left aligned]               │
└────────────────────────────────────────────────────┘
                    ↓ Scroll Up
┌────────────────────────────────────────────┐
│ [Group Name Title - Pinned]    [Share][Info]
└────────────────────────────────────────────┘
```

**Gradient Colors:**
- Start: `Theme.primary` (100% opacity)
- End: `Theme.primary` (80% opacity)

---

### Settlement Plan Section

#### Design
```
┌───────────────────────────────────────────────────────┐
│ Background: Secondary@30%                            │
│ Padding: 16px horizontal, 12px vertical              │
│                                                       │
│  Settlement Plan                          [Primary]  │
│  ├─ Alice owes Bob ₹50.00                            │
│  ├─ Charlie owes Alice ₹100.00                       │
│  └─ +1 more...                            [Primary]  │
│                                                       │
│  [or if settled up]                                  │
│  ✓ Everyone is settled up! 🎉              [Green]  │
└───────────────────────────────────────────────────────┘
```

**Typography:**
- Title: `GoogleFonts.lato(fontSize: 12, fontWeight: w700)`
- Items: `GoogleFonts.lato(fontSize: 13, fontWeight: w500)`
- "+N more": `GoogleFonts.lato(fontSize: 12, fontWeight: w500, color: Primary)`

---

### Expense Tile (Normal State)

```
┌────────────────────────────────────────────────────────┐
│  ┌──────┐                                              │
│  │ OCT  │  Coffee                          +₹100      │
│  │  24  │  Paid by Ananya                  [Green]    │
│  │      │                               You lent      │
│  └──────┘                                              │
│  [▼ Expand]                                            │
└────────────────────────────────────────────────────────┘
  Margin: 12px horizontal, 6px vertical
  Border: 1px solid grey.shade200
  Corner Radius: 12px
```

**Date Box Specifications:**
- Size: 50×50 dp
- Background: grey.shade100
- Corner Radius: 6px
- Font: Lato w700
- Month (top): 11px
- Day (bottom): 14px

**Color Coding Examples:**
```
You lent    → Colors.green.shade700
You borrowed → Colors.orange.shade700
Not involved → Colors.grey.shade600
```

---

### Expense Tile (Expanded State)

```
┌────────────────────────────────────────────────────────┐
│  ┌──────┐                                              │
│  │ OCT  │  Coffee                          +₹100      │
│  │  24  │  Paid by Ananya                  [Green]    │
│  │      │                               You lent      │
│  └──────┘                                              │
│  [▲ Collapse]                                          │
├────────────────────────────────────────────────────────┤
│  Total Amount           ₹100.00                        │
│  Date                   Oct 24, 2025                    │
│                                                        │
│  Split Details                                         │
│  ┌────────────────────────────────────────┐           │
│  │  Ananya        ₹60                     │           │
│  │  You           ₹40                     │           │
│  └────────────────────────────────────────┘           │
│                                                        │
│      [✎ Edit Expense Button - Full Width]             │
│                                                        │
└────────────────────────────────────────────────────────┘
  Expansion Padding: 12px all sides
  Split Box Background: grey.shade50
  Split Box Padding: 8px
  Split Box Corner Radius: 8px
```

---

## 🎬 Animation Behavior

### Header Collapse Animation
- **Trigger:** Vertical scroll on CustomScrollView
- **Type:** Parallax (background scales during collapse)
- **Duration:** Natural (based on scroll velocity)
- **Title Movement:** Slides up to pinned position
- **Color Fade:** Primary color maintains intensity

### Tile Expansion Animation
- **Trigger:** Tap on ExpenseTile
- **Type:** Implicit animation (setState driven)
- **Duration:** ~200ms (implicit)
- **Border Change:** Colors fade from grey.200 → primary
- **Background Change:** White → primary@5%
- **Icon Rotation:** ▼ → ▲

### Button States
- **Normal:** Outlined button with text + icon
- **Pressed:** Slightly darker background
- **Disabled:** Greyed out (if applicable)

---

## 📱 Responsive Design Breakpoints

### Mobile (Default - 360px to 480px width)
- Full-width tiles with 12px margin
- Date box: 50×50 (as specified)
- Font sizes: As specified (12-18px)
- Spacing: As specified (4-80px)

### Tablet (480px+)
- Consider max-width constraint for tiles
- Larger date box optional (55×55)
- Wider settlement plan preview possible
- All proportions maintain aspect ratio

---

## 🎯 Settlement Plan Dialog

### Modal Dialog Layout
```
╔════════════════════════════════════════╗
║  Settlement Plan                   [×] ║  <- Title
╠════════════════════════════════════════╣
║                                        ║
║  Alice → Bob                    ₹50.00 ║  <- Settlement Item
║  ┌────────────────────────────────┐   ║
║  │ [Message] Share on WhatsApp    │   ║
║  └────────────────────────────────┘   ║
║                                        ║
║  Charlie → Alice                 ₹100  ║  <- Settlement Item
║  ┌────────────────────────────────┐   ║
║  │ [Message] Share on WhatsApp    │   ║
║  └────────────────────────────────┘   ║
║                                        ║
║  [or if settled]                       ║
║  ╭─────────────────────────────────╮  ║
║  │          ✓                      │  ║
║  │  Everyone is settled up!        │  ║
║  ╰─────────────────────────────────╯  ║
║                                        ║
╠════════════════════════════════════════╣
║           [Close] [Share All?]         ║  <- Actions
╚════════════════════════════════════════╝
```

**Settlement Item Specification:**
```
┌────────────────────────────────────┐
│ Alice → Bob              ₹50.00    │  (16px padding, border 1px grey)
│ ┌────────────────────────────────┐ │
│ │ [Message] Share on WhatsApp    │ │  (Outlined button, full width)
│ └────────────────────────────────┘ │
│                                    │
└────────────────────────────────────┘
  Margin: 16px bottom
  Border: 1px solid grey.shade300
  Padding: 12px all
  Corner Radius: 8px
```

---

## 🌗 Dark Mode Considerations

The design should adapt to dark mode:
```
Light Mode:
- Card: White background
- Border: grey.shade200
- Text: grey.shade900
- Amount (green): Colors.green.shade700
- Amount (orange): Colors.orange.shade700

Dark Mode (Theme.brightness == Brightness.dark):
- Card: grey.shade900
- Border: grey.shade700
- Text: grey.shade100
- Amount (green): Colors.green.shade400
- Amount (orange): Colors.orange.shade400
```

---

## ✨ Micro-Interactions

### Hover States (Web/Desktop)
```dart
InkWell(
  onTap: () {},
  hoverColor: primary.withValues(alpha: 0.05),
  // ...
)
```

### Press States
```dart
ExpansionTile expands with:
- Border color change: grey.200 → primary
- Background color shift: white → primary@5%
- Icon rotation: 180° (expand_less ← → expand_more)
```

### Loading States
```
Expense tile loading:
┌─────────────────────────────────┐
│  [===============] Loading...   │  <- LinearProgressIndicator
└─────────────────────────────────┘

Settlement plan loading:
┌─────────────────────────────────┐
│  Settlement Plan                │
│    [Circular spinner]           │
│    Loading settlements...       │
└─────────────────────────────────┘
```

---

## 🔍 Accessibility Considerations

### Semantic Labels
```dart
Text(
  'You lent ₹100',
  semanticsLabel: 'You lent one hundred rupees', // Screen readers
)
```

### Touch Targets
- Minimum 48dp for interactive elements
- Tile height: ~64dp (normal) → ~200dp (expanded)
- Button padding: 12dp vertical (from text)

### Color Contrast
- Text on background: WCAG AA compliant
- Green.shade700 on white: ~4.5:1 ratio
- Orange.shade700 on white: ~4.2:1 ratio
- Grey.shade600 on white: ~4.5:1 ratio

### Text Scaling
- Uses MediaQuery.of(context).textScaleFactor for responsive text
- Min/max font sizes maintained per Material Design

---

## 📐 Safe Area Considerations

### iOS Notch/Dynamic Island
- SliverAppBar handles through FlexibleSpaceBar
- Actions positioned safely via AppBar API
- Content padding applied via MediaQuery.of().padding

### Android Gesture Navigation
- FAB positioned with 80dp bottom margin (accommodates nav bar)
- Sliver content respects system insets
- Back navigation via AppBar built-in

---

## 🎭 Component Variants

### ExpenseTile Variants

**Variant 1: User as Payer (Positive)**
```
Status: "You lent" | Color: Green
Applies when user.id == expense.paidBy && others in split
```

**Variant 2: User in Split (Negative)**
```
Status: "You borrowed" | Color: Orange
Applies when user.id != expense.paidBy && user in split
```

**Variant 3: User Uninvolved (Neutral)**
```
Status: "Not involved" | Color: Grey
Applies when user.id not in split && user.id != paidBy
```

### Balance Status Variants

**Positive Balance (You get back)**
```
Text: "You will get back"
Color: Green.shade700
Icon: Implied (arrow up or ⬆)
```

**Negative Balance (You owe)**
```
Text: "You owe"
Color: Orange.shade700
Icon: Implied (arrow down or ⬇)
```

**Zero Balance (Settled up)**
```
Text: "Settled up"
Color: Grey.shade600
Icon: Implied (checkmark or ✓)
```

---

## 📊 Layout Proportions

### Golden Ratios
- Balance amount to label ratio: 32px / 14px ≈ 2.3:1
- Date box proportions: 50×50 (square)
- Tile height (normal): ~70dp
- Tile height (expanded): content-based

### Spacing Harmony
```
8px gap: Micro-level (between inline elements)
12px pad: Standard (tile padding)
16px gap: Section-level (between major sections)
20px gap: Large visual break
```

---

## 🎬 Loading State Hierarchy

```
Level 1: Circular spinner (center of screen)
Level 2: Linear progress indicator (in tile)
Level 3: Skeleton loaders (future enhancement)
```

---

## 🚀 Performance Considerations

### Rendering Optimization
- SliverList: Only builds visible tiles
- CustomScrollView: Efficient viewport calculation
- Implicit animations: GPU-accelerated (no rebuilds)
- IncludeProperties: false for diagnostics (debugging)

### Memory Optimization
- Expense tiles are built on-demand
- Settlement calculation (one-time, per navigation)
- Member profiles cached via FutureProvider
- Avoid excessive rebuilds with `ConsumerWidget`

