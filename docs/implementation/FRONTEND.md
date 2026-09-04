# Frontend conventions

SearchOps is server-rendered Rails with ERB, Turbo, Stimulus and Tailwind. It is
not a separate SPA. Links and forms must retain useful HTTP behavior when
JavaScript is unavailable; Turbo enhances those same responses rather than
creating a second client-side state model.

## Layout and accessibility

`layouts/application` owns the document language, metadata, assets and skip
link. Public and authenticated layouts provide their own header/navigation,
flash region and main landmark through the base layout. New layouts preserve:

- one clearly identified `main` target with `tabindex="-1"`;
- semantic header, navigation, aside and footer landmarks;
- native controls before custom JavaScript interactions;
- visible `:focus-visible` styling and a logical DOM/tab order;
- labels, descriptions and errors associated with every form control;
- error summaries with links to invalid fields and focused arrival;
- `aria-live` flash status that does not invent client-only messages;
- reduced-motion behavior that removes non-essential animation.

The authenticated shell accepts explicit navigation/account locals. It must
not read global organization/project state in a partial or render a tenant name
until validated request context exists. Authorization is always enforced in a
controller/domain boundary; hiding a link is never the access decision.

## Reusable view contract

Partials under `app/views/shared` declare every input at the render call. Avoid
implicit instance variables or `Current` inside generic components. Escape
customer values through normal ERB output and map variants such as alert kind
through a fixed internal allowlist before using them in classes.

The initial component vocabulary is:

- typography/eyebrows and bounded content containers;
- primary, secondary, inverse, danger and icon buttons;
- labels, hints, inputs, selects, textareas, choices and field errors;
- neutral/info/success/warning/danger badges and alerts;
- cards, responsive tables, dialogs and pagination;
- honest empty states and reduced-motion loading placeholders.

Prefer these semantic classes over copying long utility strings into every
feature view. Add a variant only when a real product state needs it and keep
contrast/focus behavior consistent.

## Turbo and Stimulus

Use Turbo Frames for a bounded server-owned region and Turbo Streams for
idempotent server-originated updates. A normal full-page response remains the
fallback. Give frame IDs stable application meaning; do not derive them from
untrusted raw strings.

Stimulus controllers remain small behavior adapters. The initial `focus`
controller focuses a server-rendered error summary and owns no business state.
Prefer native `<details>`, links, buttons and forms when they already provide
the needed keyboard behavior. A controller must disconnect listeners/timers,
honor reduced motion, and leave content operable if it never connects.

## Responsive and data-heavy views

Start with the narrow viewport and add layout at Tailwind breakpoints. Keep
primary actions reachable without horizontal scrolling. Wrap wide tables in a
labeled scrolling region, keep header associations, and paginate on the server;
never render raw crawl-scale collections into the DOM.

Charts are deferred until a real metrics view exists. Introduce a charting
library only after checking bundle weight, keyboard/table fallback, textual
summary, source/freshness labels, contrast and reduced-motion behavior. Every
chart must have an equivalent accessible data table or concise value summary;
canvas pixels alone are not product evidence.

## Verification

Controller/integration tests prove semantic HTML and no-JavaScript form paths.
System tests cover keyboard focus, validation focus and narrow/wide navigation.
`bin/rails tailwindcss:build` is the CSS syntax/content check. No automated WCAG
scanner is installed yet, so the current local accessibility checks are
targeted semantic/keyboard assertions; later critical flows should add a
reviewed automated scanner plus manual screen-reader and zoom checks.
