import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { mockGoogleAuthenticatedSession } from "../../helpers/mock-api.js";

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function appOriginRegex(pathname) {
  return new RegExp(`^https?:\\/\\/[^/]+${escapeRegex(pathname)}(?:\\?.*)?$`);
}

async function drawStroke(page, points) {
  const canvas = page.locator("canvas");
  const box = await canvas.boundingBox();
  if (!box) throw new Error("Canvas bounding box unavailable");

  await page.mouse.move(box.x + points[0][0], box.y + points[0][1]);
  await page.mouse.down();
  for (const [x, y] of points.slice(1)) {
    await page.mouse.move(box.x + x, box.y + y, { steps: 6 });
  }
  await page.mouse.up();
}

test("Drawing state updates correctly after erasing strokes", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "drawing_updated_after_erasing_strokes",
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

  await recorder.step("Load draw page and create two strokes", async () => {
    await page.goto("/draw");
    await expect(page.locator("canvas")).toBeVisible();
    await drawStroke(page, [[40, 60], [80, 80], [120, 100], [160, 120]]);
    await drawStroke(page, [[220, 230], [250, 240], [280, 250], [310, 260]]);
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeEnabled();
  });

  await recorder.step("Clear canvas", async () => {
    await page.getByRole("button", { name: "Clear" }).click();
  });

  await recorder.step("Verify canvas is blank and posting is disabled", async () => {
    const stats = await page.locator("canvas").evaluate((canvas) => {
      const ctx = canvas.getContext("2d");
      const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
      let darkPixels = 0;
      for (let i = 0; i < data.length; i += 4) {
        const [r, g, b, a] = [data[i], data[i + 1], data[i + 2], data[i + 3]];
        if (a > 0 && r < 100 && g < 100 && b < 100) darkPixels += 1;
      }
      return darkPixels;
    });

    expect(stats).toBe(0);
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeDisabled();
  });

  await recorder.step("Attempt to export/share after clearing", async () => {
    await page.getByRole("button", { name: "Share my drawing" }).click({ force: true });
    expect(uploadCalled).toBe(false);
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:drawing_updated_after_erasing_strokes");
  await recorder.save(testInfo);
});
