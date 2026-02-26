import { chromium } from 'playwright';

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();

// TodoMVCを開く
await page.goto('https://demo.playwright.dev/todomvc/');
console.log('=== TodoMVCを開きました ===');

// --- STEP 1: 5つのTodoアイテムを追加 ---
const todos = ['牛乳を買う', 'レポートを書く', 'メールを返信する', '部屋を掃除する', '運動する'];
for (const todo of todos) {
  await page.locator('.new-todo').fill(todo);
  await page.locator('.new-todo').press('Enter');
  console.log(`追加: ${todo}`);
}
console.log('\n=== STEP 1: 5つのTodoを追加完了 ===\n');

// --- STEP 2: "牛乳を買う" と "メールを返信する" を完了済みにする ---
for (const label of ['牛乳を買う', 'メールを返信する']) {
  const item = page.locator(`.todo-list li`).filter({ hasText: label });
  await item.locator('.toggle').check();
  console.log(`完了済みに: ${label}`);
}
console.log('\n=== STEP 2: 2つを完了済みにしました ===\n');

// --- STEP 3: "Active" フィルタをクリック ---
await page.locator('.filters >> text=Active').click();
await page.waitForTimeout(500);
const activeItems = await page.locator('.todo-list li').allTextContents();
console.log('=== STEP 3: "Active" フィルタの表示アイテム ===');
activeItems.forEach((item, i) => console.log(`  ${i + 1}. ${item}`));
console.log(`  合計: ${activeItems.length}件\n`);

// --- STEP 4: "Completed" フィルタをクリック ---
await page.locator('.filters >> text=Completed').click();
await page.waitForTimeout(500);
const completedItems = await page.locator('.todo-list li').allTextContents();
console.log('=== STEP 4: "Completed" フィルタの表示アイテム ===');
completedItems.forEach((item, i) => console.log(`  ${i + 1}. ${item}`));
console.log(`  合計: ${completedItems.length}件\n`);

// --- STEP 5: "All" フィルタに戻し、残りアイテム数を報告 ---
await page.locator('.filters >> text=All').click();
await page.waitForTimeout(500);
const countText = await page.locator('.todo-count').textContent();
console.log('=== STEP 5: "All" フィルタ - 残りアイテム数 ===');
console.log(`  フッター表示: ${countText}\n`);

// ブラウザを閉じる
await browser.close();
console.log('=== ブラウザを閉じました。操作完了 ===');
