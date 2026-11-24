import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";

const supabase = createClient(
  "https://tzkxujrjrhyqxgzytaex.supabase.co",
  "sb_publishable_BrNnF8XCshRm1NmEYvQphg_hcNIJhQV"
);

const $ = id => document.getElementById(id);

const languages = [
  ["ru", "🇷🇺 Русский"],
  ["uk", "🇺🇦 Українська"],
  ["en", "🇺🇸 English (US)"],
  ["fr", "🇫🇷 Français"]
];


const uiTranslations = {
  uk: {
    "Чаты": "Чати", "💬 Чаты": "💬 Чати", "Лента": "Стрічка", "▤ Лента": "▤ Стрічка", "Друзья": "Друзі", "👥 Друзья": "👥 Друзі", "Группы": "Групи", "👨‍👩‍👧‍👦 Группы": "👨‍👩‍👧‍👦 Групи", "Каналы": "Канали", "📢 Каналы": "📢 Канали", "Звонки": "Дзвінки", "📞 Звонки": "📞 Дзвінки", "Контакты": "Контакти", "📇 Контакты": "📇 Контакти", "Профиль": "Профіль", "👤 Профиль": "👤 Профіль", "Настройки": "Налаштування", "⚙️ Настройки": "⚙️ Налаштування", "Выйти": "Вийти", "Подарки": "Подарунки", "Поиск людей": "Пошук людей", "Приложение": "Застосунок", "Управление": "Керування", "Help": "Допомога", "Мои друзья": "Мої друзі", "Входящие заявки": "Вхідні запити", "Отправить": "Надіслати", "Напиши сообщение...": "Напиши повідомлення...", "Создать публикацию": "Створити допис", "Опубликовать": "Опублікувати", "Мой профиль": "Мій профіль", "Мои достижения": "Мої досягнення", "Язык интерфейса": "Мова інтерфейсу", "Выбери язык": "Оберіть мову", "Сохранить": "Зберегти", "Поиск пользователей": "Пошук користувачів", "Найти людей": "Знайти людей", "Открыть чат": "Відкрити чат", "Подписаться": "Підписатися", "Создать канал": "Створити канал", "Создать группу": "Створити групу"
  },
  en: {
    "Чаты": "Chats", "💬 Чаты": "💬 Chats", "Лента": "Feed", "▤ Лента": "▤ Feed", "Друзья": "Friends", "👥 Друзья": "👥 Friends", "Группы": "Groups", "👨‍👩‍👧‍👦 Группы": "👨‍👩‍👧‍👦 Groups", "Каналы": "Channels", "📢 Каналы": "📢 Channels", "Звонки": "Calls", "📞 Звонки": "📞 Calls", "Контакты": "Contacts", "📇 Контакты": "📇 Contacts", "Профиль": "Profile", "👤 Профиль": "👤 Profile", "Настройки": "Settings", "⚙️ Настройки": "⚙️ Settings", "Выйти": "Log out", "Подарки": "Gifts", "Поиск людей": "Find people", "Приложение": "App", "Управление": "Admin", "Help": "Help", "Мои друзья": "My friends", "Входящие заявки": "Incoming requests", "Отправить": "Send", "Напиши сообщение...": "Write a message...", "Создать публикацию": "Create a post", "Опубликовать": "Publish", "Мой профиль": "My profile", "Мои достижения": "My achievements", "Язык интерфейса": "Interface language", "Выбери язык": "Choose language", "Сохранить": "Save", "Поиск пользователей": "Find users", "Найти людей": "Find people", "Открыть чат": "Open chat", "Подписаться": "Subscribe", "Создать канал": "Create channel", "Создать группу": "Create group"
  },
  fr: {
    "Чаты": "Discussions", "Лента": "Fil", "Друзья": "Amis", "Группы": "Groupes", "Каналы": "Chaînes", "Звонки": "Appels", "Контакты": "Contacts", "📇 Контакты": "📇 Contacts", "Профиль": "Profil", "Настройки": "Paramètres", "Выйти": "Déconnexion", "Подарки": "Cadeaux", "Поиск людей": "Trouver des personnes", "Приложение": "Application", "Управление": "Administration", "Help": "Aide", "Мои друзья": "Mes amis", "Отправить": "Envoyer", "Опубликовать": "Publier", "Мой профиль": "Mon profil", "Мои достижения": "Mes succès", "Язык интерфейса": "Langue de l’interface", "Выбери язык": "Choisir la langue", "Сохранить": "Enregistrer", "Подписаться": "S’abonner"
  }
};
const originalTextNodes = new WeakMap();
function applyInterfaceTranslations(language = "ru", root = document.body) {
  const dictionary = uiTranslations[language] || {};
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const nodes = [];
  while (walker.nextNode()) nodes.push(walker.currentNode);
  for (const node of nodes) {
    if (!originalTextNodes.has(node)) originalTextNodes.set(node, node.nodeValue);
    const original = originalTextNodes.get(node);
    const trimmed = original.trim();
    if (!trimmed) continue;
    const translated = dictionary[trimmed];
    if (translated) node.nodeValue = original.replace(trimmed, translated);
    else if (language === "ru") node.nodeValue = original;
  }
  root.querySelectorAll("input[placeholder],textarea[placeholder]").forEach(el => {
    if (!el.dataset.originalPlaceholder) el.dataset.originalPlaceholder = el.placeholder;
    const original = el.dataset.originalPlaceholder;
    el.placeholder = dictionary[original] || (language === "ru" ? original : el.placeholder);
  });
}
let translationObserver = null;
function watchInterfaceTranslations(language) {
  applyInterfaceTranslations(language);
  translationObserver?.disconnect();
  translationObserver = new MutationObserver(records => {
    for (const record of records) {
      for (const node of record.addedNodes) {
        if (node.nodeType === Node.ELEMENT_NODE) applyInterfaceTranslations(language, node);
        else if (node.nodeType === Node.TEXT_NODE) {
          const parent = node.parentElement;
          if (parent) applyInterfaceTranslations(language, parent);
        }
      }
    }
  });
  translationObserver.observe(document.body, { childList: true, subtree: true });
}

const themes = [
  ["burgundy", "🍷 Бордовая классика"],
  ["dark", "🌑 Тёмная"],
  ["midnight", "🌌 Полуночная"],
  ["forest", "🌲 Лесная"],
  ["lavender", "💜 Лавандовая"],
  ["graphite", "⚙️ Графитовая"]
];

let currentUser = null;
let currentProfile = null;

function notify(message) {
  const target = $("globalMessage");
  if (target) target.textContent = message;
}

function escapeHTML(value = "") {
  return String(value).replace(/[&<>"']/g, char => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;"
  })[char]);
}

function addStyles() {
  if ($("extrasStyles")) return;

  const style = document.createElement("style");
  style.id = "extrasStyles";

  style.textContent = `
    body[data-theme="burgundy"] {
      --wine:#641b2b;
      --wine2:#42101d;
      --pale:#f2e5e8;
      --bg:#e9e2e4;
      --paper:#fff;
      --ink:#292126;
      --line:#ded0d4;
      --muted:#81747a;
    }

    body[data-theme="midnight"] {
      --wine:#263d78;
      --wine2:#14264f;
      --pale:#e4ebff;
      --bg:#e6eaf4;
      --paper:#fff;
      --ink:#202a42;
      --line:#cbd4e8;
      --muted:#71809e;
    }

    body[data-theme="forest"] {
      --wine:#286344;
      --wine2:#163e2b;
      --pale:#e1f0e6;
      --bg:#e5eee7;
      --paper:#fff;
      --ink:#20382b;
      --line:#c6d9cc;
      --muted:#718579;
    }

    body[data-theme="lavender"] {
      --wine:#7954a6;
      --wine2:#50336f;
      --pale:#eee5f8;
      --bg:#eee9f4;
      --paper:#fff;
      --ink:#30253d;
      --line:#d8cce7;
      --muted:#897b98;
    }

    body[data-theme="graphite"] {
      --wine:#41464e;
      --wine2:#252a31;
      --pale:#e3e5e8;
      --bg:#dfe1e4;
      --paper:#f9fafb;
      --ink:#24272c;
      --line:#c6c9ce;
      --muted:#747a83;
    }

    body[data-theme="dark"] {
      --wine:#73354b;
      --wine2:#45202e;
      --pale:#382a30;
      --bg:#191518;
      --paper:#292226;
      --ink:#f5edf0;
      --line:#4b3940;
      --muted:#b9aab0;
    }

    .language-settings {
      margin-top:20px;
      padding-top:18px;
      border-top:1px solid var(--line);
    }

    .language-settings select {
      width:100%;
      margin-top:8px;
    }

    .owner-achievement-box {
      margin-top:20px;
      padding:18px;
      border:1px solid var(--line);
      border-left:4px solid var(--wine);
      border-radius:12px;
      background:var(--pale);
    }

    .owner-achievement-box select {
      width:100%;
      margin:10px 0;
      background:var(--paper);
      color:var(--ink);
    }

    .owner-achievement-box button {
      margin-top:8px;
    }
  `;

  document.head.appendChild(style);
}

function applyTheme(theme) {
  if (!themes.some(item => item[0] === theme)) {
    theme = "burgundy";
  }

  document.body.dataset.theme = theme;
  document.body.classList.toggle("dark", theme === "dark");

  localStorage.setItem("apple-theme", theme);

  const select = $("themeSelect");
  if (select) select.value = theme;
}

async function saveLanguage(language) {
  if (!languages.some(item => item[0] === language)) return;

  document.documentElement.lang = language;
  document.documentElement.dir = "ltr";
  watchInterfaceTranslations(language);

  localStorage.setItem("apple-language", language);

  if (!currentUser) {
    notify("Язык сохранён на этом устройстве.");
    return;
  }

  const { error } = await supabase
    .from("profiles")
    .update({ language })
    .eq("id", currentUser.id);

  if (error) {
    notify("Ошибка сохранения языка: " + error.message);
    return;
  }

  if (currentProfile) currentProfile.language = language;

  notify("Язык сохранён.");
}

function addLanguageSettings() {
  const settings = $("page-settings");

  if (!settings || $("languageSettings")) return;

  const firstPanel = settings.querySelector(".panel");
  if (!firstPanel) return;

  const box = document.createElement("div");

  box.id = "languageSettings";
  box.className = "language-settings";

  box.innerHTML = `
    <h3>🌍 Язык интерфейса</h3>
    <label for="languageSelect">Выбери язык</label>

    <select id="languageSelect">
      ${languages.map(([code, name]) =>
        `<option value="${code}">${name}</option>`
      ).join("")}
    </select>
  `;

  firstPanel.appendChild(box);

  const select = $("languageSelect");

  select.value =
    currentProfile?.language ||
    localStorage.getItem("apple-language") ||
    "ru";

  select.addEventListener("change", () => {
    saveLanguage(select.value);
  });
}

function setupThemes() {
  const select = $("themeSelect");
  if (!select) return;

  select.innerHTML = themes.map(([code, name]) =>
    `<option value="${code}">${name}</option>`
  ).join("");

  select.value = localStorage.getItem("apple-theme") || "burgundy";

  applyTheme(select.value);

  const button = $("saveTheme");

  if (button && !button.dataset.extrasBound) {
    button.dataset.extrasBound = "true";

    button.addEventListener("click", () => {
      applyTheme(select.value);
      notify("Тема оформления сохранена.");
    });
  }

  select.addEventListener("change", () => {
    applyTheme(select.value);
  });
}

async function addOwnerAchievementPanel() {
  if (!currentProfile || currentProfile.role !== "owner") return;

  const page = $("page-profile");

  if (!page || $("ownerAchievementPanel")) return;

  const panel = document.createElement("div");

  panel.id = "ownerAchievementPanel";
  panel.className = "panel pad owner-achievement-box";

  panel.innerHTML = `
    <h2>👑 OWNER CONTROL</h2>

    <p class="muted">Управление собственными достижениями.</p>

    <label for="ownerAchievementSelect">
      Выбери достижение
    </label>

    <select id="ownerAchievementSelect">
      <option value="">Загрузка...</option>
    </select>

    <button id="ownerGiveAchievement" class="primary">
      Выдать достижение себе
    </button>

    <p id="ownerAchievementMessage" class="notice"></p>
  `;

  page.appendChild(panel);

  const select = $("ownerAchievementSelect");
  const message = $("ownerAchievementMessage");
  const button = $("ownerGiveAchievement");

  const { data, error } = await supabase
    .from("achievement_definitions")
    .select("code,title,icon")
    .order("title");

  if (error) {
    select.innerHTML = `<option value="">Ошибка загрузки</option>`;
    message.textContent = error.message;
    return;
  }

  if (!data?.length) {
    select.innerHTML = `<option value="">Нет доступных достижений</option>`;
    return;
  }

  select.innerHTML = data.map(item => `
    <option value="${escapeHTML(item.code)}">
      ${escapeHTML(item.icon || "🏆")} ${escapeHTML(item.title || item.code)}
    </option>
  `).join("");

  button.addEventListener("click", async () => {
    const code = select.value;

    if (!code) return;

    button.disabled = true;
    message.textContent = "Выдаём достижение...";

    const { error } = await supabase.rpc(
      "owner_grant_my_achievement",
      { p_achievement_code: code }
    );

    button.disabled = false;

    if (error) {
      message.textContent = "Ошибка: " + error.message;
      return;
    }

    message.textContent = "🏆 Достижение успешно добавлено!";

    window.dispatchEvent(
      new Event("apple-achievements-refresh")
    );
  });
}

async function initializeExtras() {
  addStyles();

  const savedTheme = localStorage.getItem("apple-theme") || "burgundy";
  applyTheme(savedTheme);
  setupThemes();

  const {
    data: { user },
    error: authError
  } = await supabase.auth.getUser();

  if (authError || !user) {
    currentUser = null;
    currentProfile = null;
    return;
  }

  currentUser = user;

  const { data: profile, error } = await supabase
    .from("profiles")
    .select("id,role,language")
    .eq("id", user.id)
    .single();

  if (error || !profile) {
    console.error("Extras profile:", error);
    return;
  }

  currentProfile = profile;

  const language =
    profile.language ||
    localStorage.getItem("apple-language") ||
    "ru";

  document.documentElement.lang = language;
  document.documentElement.dir = "ltr";
  watchInterfaceTranslations(language);

  localStorage.setItem("apple-language", language);

  addLanguageSettings();
  setupThemes();
  await addOwnerAchievementPanel();
}

document.addEventListener("click", event => {
  if (event.target.closest('[data-page="settings"]')) {
    setTimeout(() => {
      addLanguageSettings();
      setupThemes();
    }, 200);
  }

  if (event.target.closest('[data-page="profile"]')) {
    setTimeout(addOwnerAchievementPanel, 200);
  }
});

supabase.auth.onAuthStateChange(event => {
  if (event === "SIGNED_OUT") {
    currentUser = null;
    currentProfile = null;
    $("ownerAchievementPanel")?.remove();
  }

  if (event === "SIGNED_IN") {
    setTimeout(initializeExtras, 500);
  }
});

initializeExtras();
