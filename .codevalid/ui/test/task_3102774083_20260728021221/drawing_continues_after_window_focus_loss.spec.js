import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockDrawingUploadSuccess,
} from "../../helpers/mock-api.js";
import { uploadedGoogleDrawing } from "../../mock/mock-data.js";

async function inkCount(page) {
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

test("drawing_continues_after_window_focus_loss", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "drawing_continues_after_window_focus_loss",
    testTitle: testInfo.title,
  });

  await recorder.step("setup drawing page", async () => {
    await mockGoogleAuthenticatedSession(page);
    await mockDrawingUploadSuccess(page, uploadedGoogleDrawing);
    await page.goto("/draw");
    await expect(page.locator("canvas")).toBeVisible();
  });

  const canvas = page.locator("canvas");
  const box = await canvas.boundingBox();
  if (!box) throw new Error("Canvas bounding box unavailable");

  await recorder.step("draw first portion of stroke", async () => {
    await page.mouse.move(box.x + box.width * 0.15, box.y + box.height * 0.3);
    await page.mouse.down();
    await page.mouse.move(box.x + box.width * 0.45, box.y + box.height * 0.45, { steps: 10 });
    await page.mouse.up();
  });

  let beforeBlur = 0;
  await recorder.step("capture state before focus loss", async () => {
    beforeBlur = await inkCount(page);
    expect(beforeBlur).toBeGreaterThan(300);
  });

  await recorder.step("simulate focus loss and return", async () => {
    await page.evaluate(() => window.dispatchEvent(new Event("blur")));
    await page.waitForTimeout(3000);
    await page.evaluate(() => window.dispatchEvent(new Event("focus")));
  });

  await recorder.step("continue drawing after focus restore", async () => {
    await page.mouse.move(box.x + box.width * 0.46, box.y + box.height * 0.46);
    await page.mouse.down();
    await page.mouse.move(box.x + box.width * 0.8, box.y + box.height * 0.7, { steps: 10 });
    await page.mouse.up();
  });

  await recorder.step("assert state preserved and additional stroke rendered", async () => {
    const afterFocusRestore = await inkCount(page);
    expect(afterFocusRestore).toBeGreaterThan(beforeBlur);
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeEnabled();
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:drawing_continues_after_window_focus_loss");
  await recorder.save(testInfo);
});
