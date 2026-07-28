import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { mockGoogleAuthenticatedSession } from "../../helpers/mock-api.js";

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function appOriginRegex(pathname) {
  return new RegExp(`^https?:\\/\\/[^/]+${escapeRegex(pathname)}(?:\\?.*)?$`);
}

test("Empty canvas produces an empty digital drawing object", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "empty_canvas_generates_empty_drawing",
    testTitle: testInfo.title,
  });

  await mockGoogleAuthenticatedSession(page);

  let uploadCalled = false;
  await page.route(appOriginRegex("/api/upload"), async (route) => {
    uploadCalled = true;
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ ok: true }),
    });
  });

  await recorder.step("Open draw page", async () => {
    await page.goto("/draw");
    await expect(page.locator("canvas")).toBeVisible();
  });

  await recorder.step("Verify empty canvas has no visible stroke content", async () => {
    const emptyStats = await page.locator("canvas").evaluate((canvas) => {
      const ctx = canvas.getContext("2d");
      const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
      let darkPixels = 0;
      for (let i = 0; i < data.length; i += 4) {
        const [r, g, b, a] = [data[i], data[i + 1], data[i + 2], data[i + 3]];
        if (a > 0 && r < 100 && g < 100 && b < 100) darkPixels += 1;
      }
      return {
        darkPixels,
        width: canvas.width,
        height: canvas.height,
        dataUrlPrefix: canvas.toDataURL("image/jpeg").slice(0, 23),
      };
    });

    expect(emptyStats.width).toBeGreaterThan(0);
    expect(emptyStats.height).toBeGreaterThan(0);
    expect(emptyStats.darkPixels).toBe(0);
    expect(emptyStats.dataUrlPrefix).toBe("data:image/jpeg;base64,");
  });

  await recorder.step("Verify share action cannot proceed for an empty drawing", async () => {
    const shareButton = page.getByRole("button", { name: "Share my drawing" });
    await expect(shareButton).toBeDisabled();
    await shareButton.click({ force: true });
    expect(uploadCalled).toBe(false);
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:empty_canvas_generates_empty_drawing");
  await recorder.save(testInfo);
});
