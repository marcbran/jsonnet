local c = {
  list:
    local style = |||
      @scope (.list) {
        :scope {
          font-family: monospace;
          display: inline-flex;
          flex-direction: column;
          gap: 0.25em;
        }
        a {
          color: var(--primary-color);
          border-radius: 0.5em;
        }
        a:hover {
          text-decoration: none;
        }
        a:focus {
          outline: 2px solid var(--primary-color);
          outline-offset: 2px;
        }
        ul {
          list-style: none;
          margin: 0;
          padding: 0;
        }
      }
    |||;

    local itemList = {
      local c = self,
      items:: error 'ItemList requires items',
      html: {
        element: 'ul',
        children: [
          {
            element: 'li',
            children: [{
              element: 'a',
              attributes: { href: item.link } + (
                if std.get(item, 'external', false)
                then { target: '_blank', rel: 'noopener noreferrer' }
                else {}
              ),
              children: [item.text],
            }],
          }
          for item in c.items
        ],
      },
    };

    {
      local c = self,
      items:: error 'List requires items',
      groups:: [],
      style:: '',
      html: [
        { element: 'style', children: [style] },
        {
          element: 'aside',
          attributes: { class: 'list' } + (if c.style != '' then { style: c.style } else {}),
          children:
            (if std.length(c.items) > 0 then [{
               element: 'nav',
               attributes: { class: 'card' },
               children: [itemList { items:: c.items }],
             }] else []) + [
              {
                element: 'nav',
                attributes: { class: 'card' },
                children: [
                  { element: 'strong', children: [group.title] },
                  itemList { items:: group.items },
                ],
              }
              for group in c.groups
            ],
        },
      ],
    },
  table:
    local style = |||
      @scope (.table-card) {
        :scope.card {
          padding: 0.25em;
        }
        :scope {
          display: inline-flex;
          flex-direction: column;
          align-items: flex-start;
          gap: 0.5em;
        }
      }
      @scope (.table) {
        :scope {
          border-collapse: separate;
          border-spacing: 0;
          font-family: monospace;
        }
        th {
          color: var(--primary-color);
          font-weight: bold;
          padding: 0.3em 0.4em;
          cursor: pointer;
          user-select: none;
          white-space: nowrap;
        }
        th:hover {
          text-decoration: underline;
        }
        th.sort-asc::after {
          content: ' ↑';
        }
        th.sort-desc::after {
          content: ' ↓';
        }
        td {
          padding: 0;
          border-top: 2px solid transparent;
          border-bottom: 2px solid transparent;
        }
        td:first-child {
          border-left: 2px solid transparent;
        }
        td:last-child {
          border-right: 2px solid transparent;
        }
        td > * {
          display: block;
          box-sizing: border-box;
          height: 100%;
          padding: 0.3em 0.4em;
        }
        td > a {
          text-decoration: none;
          color: var(--on-background-color);
        }
        tbody tr:has(a):hover {
          background-color: var(--container-low-color);
        }
        tbody tr:has(a:focus) td {
          background-color: var(--container-low-color);
          border-color: var(--primary-color);
        }
        tbody tr:has(a:focus) td:first-child {
          border-radius: 0.8em 0 0 0.8em;
        }
        tbody tr:has(a:focus) td:last-child {
          border-radius: 0 0.8em 0.8em 0;
        }
        td > a:focus {
          outline: none;
        }
        td.empty {
          text-align: center;
          opacity: 0.6;
        }
      }
      @scope (.table-pagination) {
        :scope {
          display: flex;
          align-items: stretch;
          width: fit-content;
          border: 1px solid var(--border-color);
          border-radius: 0.5em;
          overflow: hidden;
          background: var(--container-low-color);
          font-family: monospace;
        }
        a, span.disabled {
          display: flex;
          align-items: center;
          justify-content: center;
          line-height: 1;
          width: 2.6rem;
          height: 2.6rem;
          font-size: 1.4em;
          border-right: 1px solid var(--border-color);
          text-decoration: none;
          color: var(--on-background-color);
        }
        a:last-child, span.disabled:last-child {
          border-right: none;
        }
        a:hover {
          background-color: var(--background-color);
        }
        span.disabled {
          opacity: 0.4;
        }
      }
    |||;

    local sortScript = |||
      (function () {
        if (window.__tableSortBound) return;
        window.__tableSortBound = true;

        var observer = null;

        function headers(table) {
          return Array.prototype.slice.call(table.querySelectorAll('thead th'));
        }

        function cellText(row, i) {
          var td = row.children[i];
          return td ? td.textContent.trim() : '';
        }

        function compare(a, b) {
          var na = Number(a);
          var nb = Number(b);
          if (a !== '' && b !== '' && !isNaN(na) && !isNaN(nb)) return na - nb;
          return a.localeCompare(b);
        }

        function firstCol(table) {
          var th = table.querySelector('thead th');
          return th ? th.dataset.col : null;
        }

        function apply(table) {
          var ths = headers(table);
          ths.forEach(function (th) { th.classList.remove('sort-asc', 'sort-desc'); });
          if (ths.length === 0) return;
          var key = window.hashParams.get('sort');
          var desc = window.hashParams.get('dir') === 'desc';
          var i = 0;
          if (key) {
            i = -1;
            ths.forEach(function (th, idx) { if (th.dataset.col === key) i = idx; });
            if (i < 0) { i = 0; desc = false; }
          } else {
            desc = false;
          }
          ths[i].classList.add(desc ? 'sort-desc' : 'sort-asc');
          var tbody = table.querySelector('tbody');
          if (!tbody || tbody.querySelector('td.empty')) return;
          var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr'));
          rows.sort(function (a, b) {
            var r = compare(cellText(a, i), cellText(b, i));
            return desc ? -r : r;
          });
          rows.forEach(function (r) { tbody.appendChild(r); });
        }

        function applyAll() {
          if (observer) observer.disconnect();
          document.querySelectorAll('table.table').forEach(apply);
          if (observer) {
            var target = document.getElementById('node') || document.body;
            if (target) observer.observe(target, { childList: true, subtree: true });
          }
        }

        document.addEventListener('click', function (e) {
          var th = e.target.closest ? e.target.closest('th') : null;
          if (!th || !th.dataset.col) return;
          var table = th.closest('table.table');
          if (!table) return;
          var key = th.dataset.col;
          var first = firstCol(table);
          var curKey = window.hashParams.get('sort') || first;
          var curDesc = window.hashParams.get('dir') === 'desc';
          var nextKey;
          var nextDesc;
          if (curKey !== key) {
            nextKey = key;
            nextDesc = false;
          } else if (!curDesc) {
            nextKey = key;
            nextDesc = true;
          } else {
            nextKey = first;
            nextDesc = false;
          }
          if (nextKey === first && !nextDesc) {
            window.hashParams.remove('sort');
            window.hashParams.remove('dir');
          } else {
            window.hashParams.set('sort', nextKey);
            if (nextDesc) window.hashParams.set('dir', 'desc');
            else window.hashParams.remove('dir');
          }
          applyAll();
        });

        function init() {
          observer = new MutationObserver(applyAll);
          applyAll();
        }

        if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
        else init();
      })();
    |||;

    local slug(label) = std.asciiLower(std.strReplace(std.toString(label), ' ', '-'));

    local cellValue(item, col) =
      if std.objectHas(col, 'value') then col.value(item)
      else std.foldl(
        function(acc, k) if std.type(acc) == 'object' then std.get(acc, k, null) else null,
        col.path,
        item
      );

    local cellText(item, col) =
      local val = cellValue(item, col);
      if val == null then '' else std.toString(val);

    local rowHref(rowLink, item) =
      if rowLink == null then null
      else
        local target = rowLink(item);
        if std.type(target) == 'object' && std.objectHasAll(target, '_queryPath')
        then target._queryPath
        else null;

    local cell = {
      local c = self,
      item:: error 'Cell requires item',
      col:: error 'Cell requires col',
      href:: null,
      first:: true,
      local text = cellText(c.item, c.col),
      html:
        if c.href == null then
          { element: 'span', children: [text] }
        else
          { element: 'a', attributes: { href: c.href } + (if c.first then {} else { tabindex: '-1' }), children: [text] },
    };

    local emptyRow = {
      local c = self,
      columnCount:: error 'EmptyRow requires columnCount',
      html: {
        element: 'tr',
        children: [{
          element: 'td',
          attributes: { class: 'empty', colspan: std.max(1, c.columnCount) },
          children: [{ element: 'span', children: ['No items'] }],
        }],
      },
    };

    local navLink = {
      local c = self,
      icon:: error 'NavLink requires icon',
      title:: error 'NavLink requires title',
      href:: null,
      html:
        if c.href == null then
          { element: 'span', attributes: { class: 'disabled', title: c.title }, children: [c.icon] }
        else
          { element: 'a', attributes: { href: c.href, title: c.title }, children: [c.icon] },
    };

    local paginationDirections = [
      { key: 'first', icon: '«', title: 'First page' },
      { key: 'prev', icon: '‹', title: 'Previous page' },
      { key: 'next', icon: '›', title: 'Next page' },
      { key: 'last', icon: '»', title: 'Last page' },
    ];

    local paginationNav = {
      local c = self,
      pagination:: null,
      local links = if c.pagination == null then {} else c.pagination,
      visible:: std.length(std.objectFields(links)) > 0,
      html: {
        element: 'div',
        attributes: { class: 'table-pagination' },
        children: [
          local target = std.get(links, dir.key, null);
          (navLink {
             icon:: dir.icon,
             title:: dir.title,
             href:: if target == null then null else target._queryPath,
           }).html
          for dir in paginationDirections
        ],
      },
    };

    {
      local c = self,
      items:: error 'Table requires items',
      columns:: [],
      rowLink:: null,
      pagination:: null,
      local rows = if std.isArray(c.items) then c.items else [],
      local nav = paginationNav { pagination:: c.pagination },
      html: [
        { element: 'style', children: [style] },
        {
          element: 'div',
          attributes: { class: 'card table-card' },
          children: [
            {
              element: 'table',
              attributes: { class: 'table' },
              children: [
                {
                  element: 'thead',
                  children: [{
                    element: 'tr',
                    children: [
                      { element: 'th', attributes: { 'data-col': slug(col.label) }, children: [col.label] }
                      for col in c.columns
                    ],
                  }],
                },
                {
                  element: 'tbody',
                  children:
                    if std.length(rows) == 0 then [emptyRow { columnCount:: std.length(c.columns) }]
                    else [
                      local href = rowHref(c.rowLink, item);
                      {
                        element: 'tr',
                        children: [
                          { element: 'td', children: [cell { item:: item, col:: c.columns[i], href:: href, first:: i == 0 }] }
                          for i in std.range(0, std.length(c.columns) - 1)
                        ],
                      }
                      for item in rows
                    ],
                },
              ],
            },
          ] + (if nav.visible then [nav.html] else []),
        },
        { element: 'script', children: [{ html: sortScript }] },
      ],
    },
  yaml:
    local yaml = {
      local c = self,

      indent(depth)::
        std.join('', std.makeArray(depth * 2, function(_) ' ')),

      scalar(v)::
        if std.type(v) == 'null' then 'null'
        else if std.type(v) == 'boolean' then (if v then 'true' else 'false')
        else if std.type(v) == 'object' then '{}'
        else if std.type(v) == 'array' then '[]'
        else '%s' % v,

      key(k)::
        { element: 'span', attributes: { style: 'color: var(--primary-color); font-weight: bold' }, children: [k] },

      row(key, value, depth, bullet)::
        local hasChildren =
          (std.type(value) == 'object' || std.type(value) == 'array')
          && std.length(value) > 0;
        if hasChildren then
          [{ element: 'div', children: [
            c.indent(depth),
            bullet,
            c.key(key),
            ':',
          ] }] + c.children(value, depth + 1)
        else
          [{ element: 'div', children: [
            c.indent(depth),
            bullet,
            c.key(key),
            ': ' + c.scalar(value),
          ] }],

      children(value, depth)::
        if std.type(value) == 'object' then
          std.flatMap(
            function(kv) c.row(kv.key, kv.value, depth, ''),
            std.objectKeysValues(value)
          )
        else
          std.flatMap(function(item)
            if std.type(item) == 'object' then
              local kvs = std.objectKeysValues(item);
              c.row(kvs[0].key, kvs[0].value, depth, '- ') +
              std.flatMap(function(kv) c.row(kv.key, kv.value, depth, '  '), kvs[1:])
            else
              [{ element: 'div', children: [
                c.indent(depth),
                '- ' + c.scalar(item),
              ] }]
                      , value),
    };

    local style = |||
      .yaml {
        white-space: pre-wrap;
        word-break: break-all;
      }
    |||;

    {
      local c = self,
      data:: error 'Yaml requires data',
      html: [
        { element: 'style', children: [style] },
        { element: 'pre', attributes: { class: 'yaml card' }, children: yaml.children(c.data, 0) },
      ],
    },
  page:
    local pageStyle = |||
      * {
        margin: 0;
        padding: 0;
      }
      :root {
        color-scheme: light dark;
        --primary-color: light-dark(#0451a5, #569cd6);
        --on-background-color: light-dark(
          color-mix(in srgb, var(--primary-color) 12%, black),
          color-mix(in srgb, var(--primary-color) 12%, white)
        );
        --background-color: light-dark(
          color-mix(in srgb, var(--primary-color) 3%, white),
          color-mix(in srgb, var(--primary-color) 8%, black)
        );
        --container-low-color: light-dark(
          color-mix(in srgb, var(--primary-color) 8%, white),
          color-mix(in srgb, var(--primary-color) 15%, black)
        );
        --border-color: light-dark(
          color-mix(in srgb, var(--primary-color) 20%, white),
          color-mix(in srgb, var(--primary-color) 30%, black)
        );
      }
      body {
        background-color: var(--background-color);
        color: var(--on-background-color);
        padding: 0.5em;
      }
      .card {
        display: inline-block;
        border: 1px solid var(--border-color);
        border-radius: 0.5em;
        padding: 0.75em;
      }
      .deck {
        display: contents;
      }
      .deck:has(.card ~ .card),
      .deck:has(.list):has(.yaml) {
        display: inline-flex;
        gap: 0.25em;
        border: 1px solid var(--border-color);
        border-radius: 0.5em;
        padding: 0.25em;
      }
    |||;

    local hashScript = |||
      (function () {
        if (window.hashParams) return;

        function read() {
          return new URLSearchParams(window.location.hash.slice(1));
        }

        function serialize(p) {
          var parts = [];
          p.forEach(function (value, key) {
            parts.push(value === '' ? encodeURIComponent(key) : encodeURIComponent(key) + '=' + encodeURIComponent(value));
          });
          return parts.join('&');
        }

        function write(p) {
          var s = serialize(p);
          var base = window.location.pathname + window.location.search;
          history.replaceState(null, '', s ? base + '#' + s : base);
        }

        window.hashParams = {
          get: function (key) {
            return read().get(key);
          },
          has: function (key) {
            return read().has(key);
          },
          set: function (key, value) {
            var p = read();
            if (value === null || value === undefined) p.delete(key);
            else p.set(key, value);
            write(p);
          },
          remove: function (key) {
            this.set(key, null);
          },
        };
      })();
    |||;
    local navScript = |||
      (function () {
        if (typeof HTMLElement === 'undefined') return;

        function scrapeItems() {
          var items = [];
          document.querySelectorAll('.list a[href]').forEach(function (a) {
            var text = a.textContent.trim();
            if (text) items.push({ text: text, link: a.href });
          });
          document.querySelectorAll('.table tbody tr').forEach(function (tr) {
            var a = tr.querySelector('a[href]');
            if (!a) return;
            var text = Array.prototype.map
              .call(tr.querySelectorAll('td'), function (td) { return td.textContent.trim(); })
              .filter(Boolean)
              .join('  ');
            if (text) items.push({ text: text, link: a.href });
          });
          return items;
        }

        function isBoundary(ch) {
          return ch === undefined || /[\s_\/\-.]/.test(ch);
        }

        function fuzzyScore(query, text) {
          if (!query) return 0;
          var q = query.toLowerCase();
          var t = text.toLowerCase();
          var score = 0;
          var qi = 0;
          var prev = -2;
          for (var ti = 0; ti < t.length && qi < q.length; ti++) {
            if (t[ti] === q[qi]) {
              score += ti === prev + 1 ? 3 : 1;
              if (isBoundary(t[ti - 1])) score += 2;
              prev = ti;
              qi++;
            }
          }
          return qi === q.length ? score : -1;
        }

        function rank(query, items) {
          if (!query) return items.slice();
          var scored = [];
          for (var i = 0; i < items.length; i++) {
            var s = fuzzyScore(query, items[i].text);
            if (s >= 0) scored.push({ item: items[i], score: s, index: i });
          }
          scored.sort(function (a, b) { return b.score - a.score || a.index - b.index; });
          return scored.map(function (e) { return e.item; });
        }

        var template = `
          <style>
            :host { font-family: monospace; }
            dialog {
              border: 1px solid var(--border-color);
              border-radius: 0.5em;
              background: var(--background-color);
              color: var(--on-background-color);
              padding: 0;
              width: min(90vw, 42em);
              margin-top: 12vh;
              box-shadow: 0 0.5em 2em rgba(0, 0, 0, 0.35);
            }
            dialog::backdrop { background: rgba(0, 0, 0, 0.4); }
            input {
              width: 100%;
              box-sizing: border-box;
              font: inherit;
              padding: 0.6em 0.75em;
              border: none;
              border-bottom: 1px solid var(--border-color);
              background: transparent;
              color: inherit;
              outline: none;
            }
            ul { list-style: none; margin: 0; padding: 0.25em; max-height: 50vh; overflow-y: auto; }
            li {
              padding: 0.35em 0.5em;
              border-radius: 0.25em;
              cursor: pointer;
              white-space: nowrap;
              overflow: hidden;
              text-overflow: ellipsis;
            }
            li.selected { background: var(--container-low-color); }
            li.empty { opacity: 0.6; cursor: default; }
          </style>
          <dialog part="modal">
            <input type="text" autocomplete="off" spellcheck="false" placeholder="Jump to…" />
            <ul></ul>
          </dialog>
        `;

        class QuickNav extends HTMLElement {
          connectedCallback() {
            if (!this.shadowRoot) this.attachShadow({ mode: 'open' });
            this.shadowRoot.innerHTML = template;
            this.modal = this.shadowRoot.querySelector('dialog');
            this.input = this.shadowRoot.querySelector('input');
            this.results = this.shadowRoot.querySelector('ul');
            this.items = [];
            this.matches = [];
            this.selected = 0;

            this.input.addEventListener('input', function () {
              this.selected = 0;
              this.render();
            }.bind(this));

            this.modal.addEventListener('keydown', this.onKeydown.bind(this));
            this.modal.addEventListener('click', function (e) {
              if (e.target === this.modal) this.closeModal();
            }.bind(this));
            this.modal.addEventListener('close', function () {
              window.hashParams.remove('quick-nav');
            });

            if (!window.__quickNavBound) {
              window.__quickNavBound = true;
              document.addEventListener('keydown', function (e) {
                if (e.key !== '/' || e.metaKey || e.ctrlKey || e.altKey) return;
                var el = document.activeElement;
                var tag = el && el.tagName;
                if (tag === 'INPUT' || tag === 'TEXTAREA' || (el && el.isContentEditable)) return;
                var nav = document.querySelector('quick-nav');
                if (nav && !nav.isOpen()) {
                  e.preventDefault();
                  nav.openModal();
                }
              }, true);
            }

            if (window.hashParams.has('quick-nav')) {
              requestAnimationFrame(function () { this.openModal(); }.bind(this));
            }
          }

          isOpen() {
            return !!(this.modal && this.modal.open);
          }

          openModal() {
            this.items = scrapeItems();
            this.input.value = '';
            this.selected = 0;
            this.render();
            this.modal.showModal();
            this.input.focus();
            window.hashParams.set('quick-nav', '');
          }

          closeModal() {
            if (this.modal.open) this.modal.close();
          }

          onKeydown(e) {
            if (e.key === 'ArrowDown') {
              e.preventDefault();
              this.move(1);
            } else if (e.key === 'ArrowUp') {
              e.preventDefault();
              this.move(-1);
            } else if (e.key === 'Enter') {
              e.preventDefault();
              this.choose(e.shiftKey);
            }
          }

          move(delta) {
            if (this.matches.length === 0) return;
            this.selected = (this.selected + delta + this.matches.length) % this.matches.length;
            this.highlight();
          }

          choose(keepOpen) {
            var match = this.matches[this.selected];
            if (!match) return;
            window.hashParams.remove('quick-nav');
            var url = new URL(match.link, window.location.href);
            url.hash = keepOpen ? 'quick-nav' : '';
            window.location.href = url.toString();
          }

          highlight() {
            var lis = this.results.children;
            for (var i = 0; i < lis.length; i++) {
              var on = i === this.selected;
              lis[i].classList.toggle('selected', on);
              if (on) lis[i].scrollIntoView({ block: 'nearest' });
            }
          }

          render() {
            this.matches = rank(this.input.value.trim(), this.items);
            this.results.innerHTML = '';
            if (this.matches.length === 0) {
              var empty = document.createElement('li');
              empty.className = 'empty';
              empty.textContent = 'No matches';
              this.results.appendChild(empty);
              return;
            }
            this.matches.forEach(function (match, i) {
              var li = document.createElement('li');
              li.textContent = match.text;
              if (i === this.selected) li.classList.add('selected');
              li.addEventListener('mousemove', function () {
                this.selected = i;
                this.highlight();
              }.bind(this));
              li.addEventListener('click', function () {
                this.selected = i;
                this.choose();
              }.bind(this));
              this.results.appendChild(li);
            }.bind(this));
          }
        }

        if (!customElements.get('quick-nav')) customElements.define('quick-nav', QuickNav);
      })();
    |||;

    {
      local c = self,
      fragment:: error 'HtmlPage requires a fragment',
      html: [
        { doctype: 'html' },
        {
          element: 'html',
          children: [
            {
              element: 'head',
              children: [
                { element: 'style', children: [pageStyle] },
                { element: 'script', children: [{ html: hashScript }] },
              ],
            },
            {
              element: 'body',
              children: [
                { element: 'div', attributes: { class: 'deck' }, children: c.fragment },
                { element: 'quick-nav' },
                { element: 'script', children: [{ html: navScript }] },
              ],
            },
          ],
        },
      ],
    },
  resource:
    local list =
      local style = |||
        @scope (.list) {
          :scope {
            font-family: monospace;
            display: inline-flex;
            flex-direction: column;
            gap: 0.25em;
          }
          a {
            color: var(--primary-color);
            border-radius: 0.5em;
          }
          a:hover {
            text-decoration: none;
          }
          a:focus {
            outline: 2px solid var(--primary-color);
            outline-offset: 2px;
          }
          ul {
            list-style: none;
            margin: 0;
            padding: 0;
          }
        }
      |||;

      local itemList = {
        local c = self,
        items:: error 'ItemList requires items',
        html: {
          element: 'ul',
          children: [
            {
              element: 'li',
              children: [{
                element: 'a',
                attributes: { href: item.link } + (
                  if std.get(item, 'external', false)
                  then { target: '_blank', rel: 'noopener noreferrer' }
                  else {}
                ),
                children: [item.text],
              }],
            }
            for item in c.items
          ],
        },
      };

      {
        local c = self,
        items:: error 'List requires items',
        groups:: [],
        style:: '',
        html: [
          { element: 'style', children: [style] },
          {
            element: 'aside',
            attributes: { class: 'list' } + (if c.style != '' then { style: c.style } else {}),
            children:
              (if std.length(c.items) > 0 then [{
                 element: 'nav',
                 attributes: { class: 'card' },
                 children: [itemList { items:: c.items }],
               }] else []) + [
                {
                  element: 'nav',
                  attributes: { class: 'card' },
                  children: [
                    { element: 'strong', children: [group.title] },
                    itemList { items:: group.items },
                  ],
                }
                for group in c.groups
              ],
          },
        ],
      };
    local yaml =
      local yaml = {
        local c = self,

        indent(depth)::
          std.join('', std.makeArray(depth * 2, function(_) ' ')),

        scalar(v)::
          if std.type(v) == 'null' then 'null'
          else if std.type(v) == 'boolean' then (if v then 'true' else 'false')
          else if std.type(v) == 'object' then '{}'
          else if std.type(v) == 'array' then '[]'
          else '%s' % v,

        key(k)::
          { element: 'span', attributes: { style: 'color: var(--primary-color); font-weight: bold' }, children: [k] },

        row(key, value, depth, bullet)::
          local hasChildren =
            (std.type(value) == 'object' || std.type(value) == 'array')
            && std.length(value) > 0;
          if hasChildren then
            [{ element: 'div', children: [
              c.indent(depth),
              bullet,
              c.key(key),
              ':',
            ] }] + c.children(value, depth + 1)
          else
            [{ element: 'div', children: [
              c.indent(depth),
              bullet,
              c.key(key),
              ': ' + c.scalar(value),
            ] }],

        children(value, depth)::
          if std.type(value) == 'object' then
            std.flatMap(
              function(kv) c.row(kv.key, kv.value, depth, ''),
              std.objectKeysValues(value)
            )
          else
            std.flatMap(function(item)
              if std.type(item) == 'object' then
                local kvs = std.objectKeysValues(item);
                c.row(kvs[0].key, kvs[0].value, depth, '- ') +
                std.flatMap(function(kv) c.row(kv.key, kv.value, depth, '  '), kvs[1:])
              else
                [{ element: 'div', children: [
                  c.indent(depth),
                  '- ' + c.scalar(item),
                ] }]
                        , value),
      };

      local style = |||
        .yaml {
          white-space: pre-wrap;
          word-break: break-all;
        }
      |||;

      {
        local c = self,
        data:: error 'Yaml requires data',
        html: [
          { element: 'style', children: [style] },
          { element: 'pre', attributes: { class: 'yaml card' }, children: yaml.children(c.data, 0) },
        ],
      };

    local style = |||
      .resource {
        display: flex;
        flex-wrap: wrap;
        align-items: flex-start;
        gap: 0.25em;
      }
      .resource > .yaml {
        flex: 1 1 0;
        min-width: 0;
      }
    |||;

    {
      local c = self,
      data:: error 'Resource requires data',
      items:: [],
      groups:: [],
      html: [
        { element: 'style', children: [style] },
        {
          element: 'div',
          attributes: { class: 'resource' },
          children:
            (if std.length(c.items) > 0 || std.length(c.groups) > 0 then
               [list { items:: c.items, groups:: c.groups, style:: ' min-width: 8em;' }]
             else []) + [yaml { data:: c.data }],
        },
      ],
    },
};
local html = {
  manifestHtml(tree): std.native('invoke:html')('manifestHtml', [tree]),
};
local linkspecs =
  local walk(current, remaining, buildFn) =
    if std.length(remaining) == 0 then
      if std.type(current) == 'array' then
        std.foldl(function(acc, item) acc + buildFn(item), current, {})
      else buildFn(current)
    else
      local next =
        if std.type(current) == 'object' then std.get(current, remaining[0], null)
        else null;
      if next == null then {}
      else if std.type(next) == 'array' then
        std.foldl(function(acc, item) acc + walk(item, remaining[1:], buildFn), next, {})
      else
        walk(next, remaining[1:], buildFn);

  local itemPath(item, path) =
    std.foldl(
      function(acc, seg) if std.type(acc) == 'object' then std.get(acc, seg, null) else null,
      path,
      item
    );

  local nestValue(labels, index, value) =
    if index == std.length(labels) - 1 then { [labels[index]]: value }
    else { [labels[index]]+: nestValue(labels, index + 1, value) };

  local nestKeys(keySegs, item, value) =
    local labels = [
      if std.objectHas(seg, 'const') then seg.const else std.toString(itemPath(item, seg.path))
      for seg in keySegs
    ];
    nestValue(labels, 0, value);

  local splitPrefix(valueSegs) =
    if std.length(valueSegs) == 0 then { prefix: [], suffix: [] }
    else if std.objectHas(valueSegs[0], 'param') || std.objectHas(valueSegs[0], 'path') then { prefix: [], suffix: valueSegs }
    else
      local rest = splitPrefix(valueSegs[1:]);
      { prefix: [valueSegs[0]] + rest.prefix, suffix: rest.suffix };

  local resolveBase(root, node, prefixSegs) =
    std.foldl(
      function(acc, seg)
        if std.objectHas(seg, 'const') then acc[seg.const]
        else acc[seg.origin](std.toString(node[seg.origin])),
      prefixSegs,
      root
    );

  local resolveKey(spec, item) =
    if std.type(spec) == 'string' then spec
    else
      local raw = itemPath(item, spec.path);
      if std.objectHas(spec, 'transform') then spec.transform(raw) else raw;

  local resolveFromBase(base, item, suffixSegs) =
    std.foldl(
      function(acc, seg)
        if std.objectHas(seg, 'param') then
          acc[resolveKey(seg.param, item)](std.toString(itemPath(item, seg.path)))
        else if std.objectHas(seg, 'const') then
          acc[seg.const]
        else
          acc[resolveKey(seg, item)],
      suffixSegs,
      base
    );

  local resolvable(item, valueSegs) =
    std.all(
      [itemPath(item, seg.path) != null for seg in valueSegs if std.objectHas(seg, 'path')] +
      [
        itemPath(item, seg.param.path) != null
        for seg in valueSegs
        if std.objectHas(seg, 'param') && std.type(seg.param) == 'object'
      ]
    );

  local hexDigits = '0123456789ABCDEF';

  local percentEncode(s) =
    std.join('', [
      local c = s[i];
      local cp = std.codepoint(c);
      if (cp >= 65 && cp <= 90) || (cp >= 97 && cp <= 122) || (cp >= 48 && cp <= 57)
         || c == '-' || c == '_' || c == '.' || c == '~'
      then c
      else '%' + hexDigits[std.floor(cp / 16)] + hexDigits[cp % 16]
      for i in std.range(0, std.length(s) - 1)
    ]);

  local resolveLiteralSegment(node, item, seg) =
    if std.objectHas(seg, 'const') then seg.const
    else if std.objectHas(seg, 'origin') then std.toString(node[seg.origin])
    else resolveKey(seg, item);

  local resolveLiteralSegments(node, item, segs) =
    std.foldl(function(acc, seg) acc + resolveLiteralSegment(node, item, seg), segs, '');

  local resolveQuery(node, item, queryObj) =
    local keys = std.objectFields(queryObj);
    if std.length(keys) == 0 then ''
    else '?' + std.join('&', [
      percentEncode(k) + '=' + percentEncode(resolveLiteralSegments(node, item, queryObj[k]))
      for k in keys
    ]);

  local resolveUrl(node, item, url) =
    local scheme = std.get(url, 'scheme', null);
    local host = std.get(url, 'host', []);
    local path = std.get(url, 'path', []);
    local query = std.get(url, 'query', {});
    (if scheme != null then scheme + '://' else '')
    + resolveLiteralSegments(node, item, host)
    + (
      if std.length(path) > 0 then
        '/' + std.join('/', [percentEncode(resolveLiteralSegment(node, item, seg)) for seg in path])
      else ''
    )
    + resolveQuery(node, item, query);

  local urlSegments(url) =
    std.get(url, 'host', []) + std.get(url, 'path', [])
    + std.flattenArrays([url.query[k] for k in std.objectFields(std.get(url, 'query', {}))]);

  local buildLinks(node, specs, root=import 'root') =
    std.foldl(
      function(acc, spec)
        acc + (
          if std.type(spec.value) == 'object' then
            walk(
              node.data,
              spec.at,
              function(item)
                if resolvable(item, urlSegments(spec.value))
                then nestKeys(spec.keys, item, resolveUrl(node, item, spec.value))
                else {}
            )
          else
            local split = splitPrefix(spec.value);
            local base = resolveBase(root, node, split.prefix);
            walk(
              node.data,
              spec.at,
              function(item)
                if resolvable(item, spec.value)
                then nestKeys(spec.keys, item, resolveFromBase(base, item, split.suffix))
                else {}
            )
        ),
      specs,
      {}
    );

  local rowLinkSpec(specs, at) =
    local matches = [spec for spec in specs if spec.at == at];
    if std.length(matches) == 0 then null else matches[0];

  local rowLinkFor(node, specs, at, root=import 'root') =
    local spec = rowLinkSpec(specs, at);
    if spec == null then null
    else
      local split = splitPrefix(spec.value);
      local base = resolveBase(root, node, split.prefix);
      function(item)
        if resolvable(item, spec.value) then resolveFromBase(base, item, split.suffix) else null;

  {
    buildLinks: buildLinks,
    rowLinkFor: rowLinkFor,
    withLinkSpecs: {
      linkSpecs:: [],
      links: buildLinks(self, self.linkSpecs, import 'root'),
    },
  };

local collectNeighbors(obj, textPrefix='', exclude=[]) =
  std.flatMap(
    function(k)
      if std.member(exclude, k) || std.substr(k, 0, 1) == '_' then []
      else
        local value = obj[k];
        local textPath = if textPrefix == '' then k else '%s/%s' % [textPrefix, k];
        if std.type(value) == 'string' then [{ link: value, text: textPath, external: true }]
        else if std.type(value) != 'object' then []
        else
          if std.objectHas(value, '_node') && std.objectHasAll(value, '_queryPath') then
            [{ link: value._queryPath, text: textPath }]
          else collectNeighbors(value, textPath, exclude),
    std.objectFields(obj)
  );

local isNode(value) =
  std.type(value) == 'object' && std.objectHas(value, '_node') && std.objectHasAll(value, '_queryPath');

local directNeighbors(obj, exclude=[]) =
  std.flatMap(
    function(k)
      if std.member(exclude, k) || std.substr(k, 0, 1) == '_' then []
      else
        local value = obj[k];
        if isNode(value) then [{ link: value._queryPath, text: k }] else [],
    std.objectFields(obj)
  );

local linksItems(obj) =
  local links = std.get(obj, 'links', {});
  if std.type(links) != 'object' then []
  else std.flatMap(
    function(k)
      local value = links[k];
      if isNode(value) then [{ link: value._queryPath, text: k }]
      else if std.type(value) == 'string' then [{ link: value, text: k, external: true }]
      else [],
    std.objectFields(links)
  );

local linksGroups(obj) =
  local links = std.get(obj, 'links', {});
  if std.type(links) != 'object' then []
  else std.flatMap(
    function(k)
      local value = links[k];
      if std.type(value) == 'object' && !isNode(value) then [{ title: k, items: collectNeighbors(value) }]
      else [],
    std.objectFields(links)
  );

local neighborItems(obj) = directNeighbors(obj, exclude=['data', '_view', 'links']) + linksItems(obj);

local safeGet(obj, path) =
  std.foldl(
    function(acc, k)
      if acc != null && std.isObject(acc) && std.objectHasAll(acc, k) then acc[k] else null,
    path,
    obj
  );

local baseView = {
  local n = self,
  _view:: {
    fragment: error 'view requires a fragment',
    page: c.page { fragment:: n._view.fragment },
    html: html.manifestHtml(self.page),
  },
};

local listView = baseView {
  _view+:: {
    fragment: c.list {
      items:: neighborItems($),
      groups:: linksGroups($),
    },
  },
};

local yamlView = baseView {
  _view+:: {
    fragment: c.yaml { data:: $.data },
  },
};

local tableView = baseView {
  _view+:: {
    fragment:
      local table = std.get($, 'table', {});
      local at = std.get(table, 'at', ['items']);
      local items = safeGet($.data, at);
      c.table {
        items:: items,
        columns:: std.get(table, 'columns', []),
        rowLink:: linkspecs.rowLinkFor($, std.get($, 'linkSpecs', []), at),
        pagination:: std.get(std.get($, 'links', {}), 'pagination', null),
      },
  },
};

local resourceView = baseView {
  _view+:: {
    fragment: c.resource {
      data:: $.data,
      items:: neighborItems($),
      groups:: linksGroups($),
    },
  },
};

local withNode = { node: self.view + linkspecs.withLinkSpecs };

{
  default: { view: listView } + withNode,
  list: { view: listView } + withNode,
  table: { view: tableView } + withNode,
  yaml: { view: yamlView } + withNode,
  resource: { view: resourceView } + withNode,
}
