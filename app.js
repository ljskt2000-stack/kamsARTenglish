const state = {
  posts: [],
  filtered: [],
  visible: 12,
  query: "",
  age: "",
  type: "",
  season: "",
  sort: "newest",
};

const elements = {
  grid: document.querySelector("#card-grid"),
  template: document.querySelector("#card-template"),
  search: document.querySelector("#search-input"),
  age: document.querySelector("#age-filter"),
  type: document.querySelector("#type-filter"),
  season: document.querySelector("#season-filter"),
  sort: document.querySelector("#sort-filter"),
  reset: document.querySelector("#reset-button"),
  resultCount: document.querySelector("#result-count"),
  totalCount: document.querySelector("#total-count"),
  activeFilters: document.querySelector("#active-filters"),
  loadMore: document.querySelector("#load-more"),
  loading: document.querySelector("#loading-state"),
  empty: document.querySelector("#empty-state"),
  dialog: document.querySelector("#post-dialog"),
  dialogContent: document.querySelector("#dialog-content"),
};

const normalize = (value = "") => String(value).normalize("NFKC").toLowerCase().replace(/\s+/g, " ").trim();
const asArray = (value) => Array.isArray(value) ? value : value ? [value] : [];
const escapeHtml = (value = "") => String(value).replace(/[&<>'"]/g, (char) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;"
}[char]));

function searchableText(post) {
  return normalize([
    post.title, post.theme, post.summary, post.age,
    ...asArray(post.materials), ...asArray(post.englishWords),
    ...asArray(post.englishSentences), ...asArray(post.activityType),
    ...asArray(post.season), ...asArray(post.learningPoint), ...asArray(post.tags)
  ].join(" "));
}

function uniqueValues(key) {
  return [...new Set(state.posts.flatMap((post) => asArray(post[key])).filter(Boolean))]
    .sort((a, b) => a.localeCompare(b, "ko"));
}

function populateSelect(select, values) {
  values.forEach((value) => {
    const option = document.createElement("option");
    option.value = value;
    option.textContent = value;
    select.append(option);
  });
}

function setupFilters() {
  const ages = [...new Set(state.posts.map((post) => post.age).filter(Boolean))]
    .sort((a, b) => a.localeCompare(b, "ko"));
  populateSelect(elements.age, ages);
  populateSelect(elements.type, uniqueValues("activityType"));
  populateSelect(elements.season, uniqueValues("season"));
}

function applyFilters({ resetVisible = true } = {}) {
  if (resetVisible) state.visible = 12;
  const terms = normalize(state.query).split(" ").filter(Boolean);

  state.filtered = state.posts.filter((post) => {
    const haystack = post._search;
    const queryMatch = terms.every((term) => haystack.includes(term));
    const ageMatch = !state.age || post.age === state.age;
    const typeMatch = !state.type || asArray(post.activityType).includes(state.type);
    const seasonMatch = !state.season || asArray(post.season).includes(state.season);
    return queryMatch && ageMatch && typeMatch && seasonMatch;
  });

  state.filtered.sort((a, b) => {
    if (state.sort === "oldest") return a.publishedDate.localeCompare(b.publishedDate);
    if (state.sort === "title") return a.title.localeCompare(b.title, "ko");
    return b.publishedDate.localeCompare(a.publishedDate);
  });

  render();
}

function metaValues(post) {
  const values = [];
  if (post.age) values.push(post.age);
  if (asArray(post.activityType)[0]) values.push(asArray(post.activityType)[0]);
  if (asArray(post.season)[0]) values.push(asArray(post.season)[0]);
  return values.slice(0, 3);
}

function renderCard(post, index) {
  const fragment = elements.template.content.cloneNode(true);
  const button = fragment.querySelector(".card-button");
  const image = fragment.querySelector(".card-image");
  image.src = post.thumbnail;
  image.alt = `${post.title} 대표 이미지`;
  image.addEventListener("error", () => image.classList.add("is-broken"));
  fragment.querySelector(".card-number").textContent = String(index + 1).padStart(2, "0");

  const meta = fragment.querySelector(".card-meta");
  metaValues(post).forEach((value) => {
    const chip = document.createElement("i");
    chip.textContent = value;
    meta.append(chip);
  });

  fragment.querySelector(".card-title").textContent = post.title;
  fragment.querySelector(".card-summary").textContent = post.summary || "원문에서 놀이 내용을 확인해 보세요.";

  const keywordWrap = fragment.querySelector(".card-keywords");
  asArray(post.englishWords).slice(0, 3).forEach((word) => {
    const keyword = document.createElement("i");
    keyword.textContent = word;
    keywordWrap.append(keyword);
  });

  button.addEventListener("click", () => openPost(post));
  return fragment;
}

function renderActiveFilters() {
  elements.activeFilters.replaceChildren();
  const filters = [
    ["query", state.query, "검색"], ["age", state.age, "연령"],
    ["type", state.type, "유형"], ["season", state.season, "계절"]
  ].filter(([, value]) => value);

  filters.forEach(([key, value, label]) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "filter-chip";
    button.textContent = `${label}: ${value} ×`;
    button.addEventListener("click", () => {
      state[key] = "";
      if (key === "query") elements.search.value = "";
      else elements[key].value = "";
      applyFilters();
    });
    elements.activeFilters.append(button);
  });
}

function render() {
  elements.grid.replaceChildren();
  const visiblePosts = state.filtered.slice(0, state.visible);
  visiblePosts.forEach((post, index) => elements.grid.append(renderCard(post, index)));
  elements.resultCount.textContent = state.filtered.length.toLocaleString("ko-KR");
  elements.empty.hidden = state.filtered.length !== 0;
  elements.loadMore.hidden = state.visible >= state.filtered.length;
  renderActiveFilters();
}

function resetFilters() {
  Object.assign(state, { query: "", age: "", type: "", season: "", sort: "newest", visible: 12 });
  elements.search.value = "";
  elements.age.value = "";
  elements.type.value = "";
  elements.season.value = "";
  elements.sort.value = "newest";
  applyFilters();
}

function detailBlock(title, values, className = "") {
  const items = asArray(values).filter(Boolean);
  return `<section class="detail-block ${className}">
    <h3>${escapeHtml(title)}</h3>
    ${items.length ? `<ul>${items.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul>` : '<p class="empty-value">원문에서 확인되지 않았어요.</p>'}
  </section>`;
}

function openPost(post, { updateHash = true } = {}) {
  const typesAndSeasons = [...asArray(post.activityType), ...asArray(post.season)];
  elements.dialogContent.innerHTML = `
    <div class="dialog-hero">
      <img class="dialog-image" src="${escapeHtml(post.thumbnail)}" alt="${escapeHtml(post.title)} 대표 이미지">
      <div class="dialog-heading">
        <p class="eyebrow">${escapeHtml([post.age, ...typesAndSeasons].filter(Boolean).join(" · ") || "ART & ENGLISH")}</p>
        <h2 id="dialog-title">${escapeHtml(post.title)}</h2>
        <p>${escapeHtml(post.summary)}</p>
      </div>
    </div>
    <div class="dialog-body">
      ${detailBlock("준비물", post.materials)}
      ${detailBlock("핵심 영어 단어", post.englishWords)}
      ${detailBlock("놀이 중 영어 문장", post.englishSentences, "sentences is-wide")}
      ${detailBlock("학습 포인트", post.learningPoint, "is-wide")}
    </div>
    <div class="dialog-footer">
      <time datetime="${escapeHtml(post.publishedDate)}">기록일 ${escapeHtml(post.publishedDate || "미확인")}</time>
      <a class="original-link" href="${escapeHtml(post.originalUrl)}" target="_blank" rel="noopener noreferrer">네이버 원문 보기 <span aria-hidden="true">↗</span></a>
    </div>`;

  if (!elements.dialog.open) elements.dialog.showModal();
  if (updateHash) history.replaceState(null, "", `#post=${post.id}`);
}

function closeDialog() {
  elements.dialog.close();
  if (location.hash.startsWith("#post=")) history.replaceState(null, "", location.pathname + location.search);
}

function openFromHash() {
  const id = location.hash.match(/^#post=(\d+)$/)?.[1];
  const post = state.posts.find((item) => item.id === id);
  if (post) openPost(post, { updateHash: false });
}

function bindEvents() {
  let searchTimer;
  elements.search.addEventListener("input", (event) => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => {
      state.query = event.target.value;
      applyFilters();
    }, 160);
  });
  [[elements.age, "age"], [elements.type, "type"], [elements.season, "season"], [elements.sort, "sort"]]
    .forEach(([element, key]) => element.addEventListener("change", (event) => {
      state[key] = event.target.value;
      applyFilters();
    }));
  elements.reset.addEventListener("click", resetFilters);
  document.querySelector("[data-reset]").addEventListener("click", resetFilters);
  elements.loadMore.addEventListener("click", () => {
    state.visible += 12;
    applyFilters({ resetVisible: false });
  });
  document.querySelector(".dialog-close").addEventListener("click", closeDialog);
  elements.dialog.addEventListener("click", (event) => {
    if (event.target === elements.dialog) closeDialog();
  });
  elements.dialog.addEventListener("cancel", (event) => {
    event.preventDefault();
    closeDialog();
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "/" && !/INPUT|SELECT|TEXTAREA/.test(document.activeElement.tagName)) {
      event.preventDefault();
      elements.search.focus();
    }
  });
  window.addEventListener("hashchange", openFromHash);
}

async function init() {
  bindEvents();
  try {
    const response = await fetch("data/posts.json");
    if (!response.ok) throw new Error(`데이터 요청 실패: ${response.status}`);
    const data = await response.json();
    state.posts = data.map((post) => ({ ...post, _search: searchableText(post) }));
    state.filtered = [...state.posts];
    elements.totalCount.textContent = state.posts.length.toLocaleString("ko-KR");
    setupFilters();
    applyFilters();
    openFromHash();
  } catch (error) {
    console.error(error);
    elements.empty.hidden = false;
    elements.empty.querySelector("h3").textContent = "데이터를 불러오지 못했어요";
    elements.empty.querySelector("p").textContent = "로컬에서는 웹 서버로 열어주세요. README의 실행 방법을 확인할 수 있습니다.";
  } finally {
    elements.loading.hidden = true;
  }
}

init();
