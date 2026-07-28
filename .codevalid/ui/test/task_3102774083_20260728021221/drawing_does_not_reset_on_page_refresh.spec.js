import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockDrawingUploadSuccess,
} from "../../helpers/mock-api.js";
import { uploadedGoogleDrawing } from "../../mock/mock-data.js";

async function getInkCount(page) {
  return await page.locator("canvas").evaluate((node) => {
    const canvas = node;
    const ctx = canvas.getContext("2d");
    const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
    const background = { r: 249, g: 250, b: 251 };
    let count = 0;
    for (let i = 0; i < data.length; i += 4) {
      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];
      const a = data[i + 3];
      const isBackground =
        a > 0 &&
        Math.abs(r - background.r) <= 2 &&
        Math.abs(g - background.g) <= 2 &&
        Math.abs(b - background.b) <= 2;
      if (!isBackground) count += 1;
    }
    return count;
  });
}

test("drawing_does_not_reset_on_page_refresh", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "drawing_does_not_reset_on_page_refresh",
    testTitle: testInfo.title,
  });

  await recorder.step("setup mocked draw page", async () => {
    await mockGoogleAuthenticatedSession(page);
    await mockDrawingUploadSuccess(page, uploadedGoogleDrawing);
    await page.goto("/draw");
  });

  await recorder.step("draw a vertical line", async () => {
    const canvas = page.locator("canvas");
    await expect(canvas).toBeVisible();
    const box = await canvas.boundingBox();
    if (!box) throw new Error("Canvas bounding box unavailable");
    await page.mouse.move(box.x + box.width * 0.5, box.y + box.height * 0.2);
    await page.mouse.down();
    await page.mouse.move(box.x + box.width * 0.5, box.y + box.height * 0.8, { steps: 12 });
    await page.mouse.up();
    expect(await getInkCount(page)).toBeGreaterThan(500);
  });

  await recorder.step("refresh the page", async () => {
    await page.reload();
    await expect(page.locator("canvas")).toBeVisible();
  });

  await recorder.step("assert canvas is reset", async () => {
    expect(await getInkCount(page)).toBe(0);
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeDisabled();
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:drawing_does_not_reset_on_page_refresh");
  await recorder.save(testInfo);
});
