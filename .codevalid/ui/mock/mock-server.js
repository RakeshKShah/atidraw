export async function fulfillJson(route, body, status = 200) {
  await route.fulfill({
    status,
    contentType: "application/json",
    body: JSON.stringify(body),
  });
}

export async function setupMockRoutes(page, handlers = []) {
  for (const { url, handler } of handlers) {
    await page.route(url, handler);
  }
}
