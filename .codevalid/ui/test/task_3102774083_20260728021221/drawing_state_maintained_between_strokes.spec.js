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
    await page.mouse.move(box.x + x, box.y + y, { steps: 6 });
  }
  await page.mouse.up();
}

test("Internal drawing state is preserved across multiple strokes", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "drawing_state_maintained_between_strokes",
    testTitle: testInfo.title,
  });

  await mockGoogleAuthenticatedSession(page);
  await mockDrawingUploadSuccess(page, uploadedGoogleDrawing);

  await recorder.step("Load draw page", async () => {
    await page.goto("/draw");
    await expect(page.locator("canvas")).toBeVisible();
  });

  await recorder.step("Draw first curved stroke", async () => {
    await drawStroke(page, [
      [60, 90],
      [90, 70],
      [120, 60],
      [150, 70],
      [180, 95],
    ]);
  });

  await recorder.step("Measure drawn pixel count after first stroke", async () => {
    const firstCount = await page.locator("canvas").evaluate((canvas) => {
      const ctx = canvas.getContext("2d");
      const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
      let darkPixels = 0;
      for (let i = 0; i < data.length; i += 4) {
        const [r, g, b, a] = [data[i], data[i + 1], data[i + 2], data[i + 3]];
        if (a > 0 && r < 100 && g < 100 && b < 100) darkPixels += 1;
      }
      return darkPixels;
    });
    expect(firstCount).toBeGreaterThan(20);
    page.__firstCount = firstCount;
  });

  await recorder.step("Draw second disconnected stroke", async () => {
    await drawStroke(page, [
      [230, 220],
      [255, 235],
      [280, 250],
      [305, 270],
    ]);
  });

  await recorder.step("Verify both strokes remain represented on canvas", async () => {
    const result = await page.locator("canvas").evaluate((canvas) => {
      const ctx = canvas.getContext("2d");
      const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
      let darkPixels = 0;
      let topLeftHit = 0;
      let bottomRightHit = 0;
      for (let y = 0; y < canvas.height; y++) {
        for (let x = 0; x < canvas.width; x++) {
          const i = (y * canvas.width + x) * 4;
          const [r, g, b, a] = [data[i], data[i + 1], data[i + 2], data[i + 3]];
          const isDark = a > 0 && r < 100 && g < 100 && b < 100;
          if (isDark) {
            darkPixels += 1;
            if (x < canvas.width * 0.55 && y < canvas.height * 0.55) topLeftHit += 1;
            if (x > canvas.width * 0.55 && y > canvas.height * 0.55) bottomRightHit += 1;
          }
        }
      }
      return { darkPixels, topLeftHit, bottomRightHit };
    });

    expect(result.darkPixels).toBeGreaterThan(100);
    expect(result.topLeftHit).toBeGreaterThan(20);
    expect(result.bottomRightHit).toBeGreaterThan(20);
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeEnabled();
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:drawing_state_maintained_between_strokes");
  await recorder.save(testInfo);
});
