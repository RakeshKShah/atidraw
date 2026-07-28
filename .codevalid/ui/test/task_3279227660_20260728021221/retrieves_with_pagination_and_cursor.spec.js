import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { paginatedDrawingsPage1, paginatedDrawingsPage2 } from "../../mock/mock-data.js";
import { fulfillJson } from "../../mock/mock-server.js";

test("System correctly handles paginated retrieval with cursor parameter", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "retrieves_with_pagination_and_cursor",
    testTitle: "System correctly handles paginated retrieval with cursor parameter",
  });

  await recorder.step("Mock initial and cursor-based GET /api/drawings responses", async () => {
    await page.route(/^https?:\/\/[^/]+\/api\/drawings(?:\?.*)?$/, async (route) => {
      const requestUrl = new URL(route.request().url());
      const cursor = requestUrl.searchParams.get("cursor");

      if (cursor === null) {
        await fulfillJson(route, paginatedDrawingsPage1, 200);
        return;
      }

      if (cursor === "next_token") {
        await fulfillJson(route, paginatedDrawingsPage2, 200);
        return;
      }

      await route.abort();
    });
  });

  await recorder.step("Navigate to homepage and wait for first page render", async () => {
    await page.goto("/");
    await expect(page.getByAltText("Paginated artwork 1")).toBeVisible();
    await expect(page.getByAltText("Paginated artwork 20")).toBeVisible();
  });

  await recorder.step("Verify first page contains exactly 20 primary preview images", async () => {
    await expect(page.locator('img[alt^="Paginated artwork "]')).toHaveCount(20);
    await expect(page.getByRole("button", { name: "Load more drawings" })).toBeVisible();
  });

  await recorder.step("Load the next page using the cursor-aware button", async () => {
    await page.getByRole("button", { name: "Load more drawings" }).click();
    await expect(page.getByAltText("Paginated artwork 21")).toBeVisible();
    await expect(page.getByAltText("Paginated artwork 22")).toBeVisible();
  });

  await recorder.step("Verify next page items are appended without duplication", async () => {
    await expect(page.locator('img[alt^="Paginated artwork "]')).toHaveCount(22);
    await expect(page.getByAltText("Paginated artwork 1")).toHaveCount(1);
    await expect(page.getByAltText("Paginated artwork 22")).toHaveCount(1);
    await expect(page.getByRole("button", { name: "Load more drawings" })).toHaveCount(0);
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:retrieves_with_pagination_and_cursor");
  await recorder.save(testInfo);
});
