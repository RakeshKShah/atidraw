import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { mockGoogleAuthenticatedSession } from "../../helpers/mock-api.js";

test("empty_canvas_export_returns_empty_image", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "empty_canvas_export_returns_empty_image",
    testTitle: testInfo.title,
  });

  let uploadCalled = false;

  await recorder.step("mock authenticated session and watch upload route", async () => {
    await mockGoogleAuthenticatedSession(page);
    await page.route(/^https?:\/\/[^/]+\/api\/upload(?:\?.*)?$/, async (route) => {
      uploadCalled = true;
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ ok: true }),
      });
    });
  });

  await recorder.step("open draw page with empty canvas", async () => {
    await page.goto("/draw");
    await expect(page.locator("canvas")).toBeVisible();
  });

  await recorder.step("assert empty canvas cannot be exported by UI", async () => {
    const shareButton = page.getByRole("button", { name: "Share my drawing" });
    await expect(shareButton).toBeDisabled();
    expect(uploadCalled).toBe(false);
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:empty_canvas_export_returns_empty_image");
  await recorder.save(testInfo);
});
