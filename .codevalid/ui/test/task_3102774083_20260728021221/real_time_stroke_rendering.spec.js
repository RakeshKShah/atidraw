import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockDrawingUploadSuccess,
} from "../../helpers/mock-api.js";
import { uploadedGoogleDrawing } from "../../mock/mock-data.js";

async function drawStroke(page, points) {
  const canvas = page.locator("canvas");
  const box = await canvas.boundingBox();
  if (!box) throw new Error("Canvas bounding box unavailable");

  await page.mouse.move(box.x + points[0][0], box.y + points[0][1]);
  await page.mouse.down();
  for (const [x, y] of points.slice(1)) {
    await page.mouse.move(box.x + x, box.y + y, { steps: 8 });
  }
  await page.mouse.up();
}

test("User strokes are rendered in real time on the canvas", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "real_time_stroke_rendering",
    testTitle: testInfo.title,
  });

  await mockGoogleAuthenticatedSession(page);
  await mockDrawingUploadSuccess(page, uploadedGoogleDrawing);

  await recorder.step("Open the draw page", async () => {
    await page.goto("/draw");
    await expect(page.locator("canvas")).toBeVisible();
  });

  await recorder.step("Confirm canvas starts blank and share is disabled", async () => {
    const before = await page.locator("canvas").evaluate((canvas) => {
      const ctx = canvas.getContext("2d");
      const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
      let nonBackgroundPixels = 0;
      for (let i = 0; i < data.length; i += 4) {
        const [r, g, b, a] = [data[i], data[i + 1], data[i + 2], data[i + 3]];
        if (!(r > 200 && g > 200 && b > 200 && a > 0)) nonBackgroundPixels += 1;
      }
      return nonBackgroundPixels;
    });
    expect(before).toBe(0);
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeDisabled();
  });

  await recorder.step("Draw a continuous stroke across the canvas", async () => {
    await drawStroke(page, [
      [40, 40],
      [90, 70],
      [140, 100],
      [190, 130],
      [240, 160],
      [290, 190],
    ]);
  });

  await recorder.step("Verify rendered pixels changed immediately after drawing", async () => {
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeEnabled();

    const after = await page.locator("canvas").evaluate((canvas) => {
      const ctx = canvas.getContext("2d");
      const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
      let darkPixels = 0;
      for (let i = 0; i < data.length; i += 4) {
        const [r, g, b, a] = [data[i], data[i + 1], data[i + 2], data[i + 3]];
        if (a > 0 && r < 100 && g < 100 && b < 100) darkPixels += 1;
      }
      return darkPixels;
    });

    expect(after).toBeGreaterThan(50);
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:real_time_stroke_rendering");
  await recorder.save(testInfo);
});
