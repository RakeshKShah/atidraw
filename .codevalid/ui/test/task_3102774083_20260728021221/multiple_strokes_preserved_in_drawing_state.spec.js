import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockDrawingUploadSuccess,
} from "../../helpers/mock-api.js";
import { uploadedGoogleDrawing } from "../../mock/mock-data.js";

async function getBox(page) {
  const canvas = page.locator("canvas");
  await expect(canvas).toBeVisible();
  const box = await canvas.boundingBox();
  if (!box) throw new Error("Canvas bounding box unavailable");
  return box;
}

async function drawStroke(page, points) {
  await page.mouse.move(points[0].x, points[0].y);
  await page.mouse.down();
  for (const point of points.slice(1)) {
    await page.mouse.move(point.x, point.y, { steps: 10 });
  }
  await page.mouse.up();
}

async function getInkMetrics(page) {
  return await page.locator("canvas").evaluate((node) => {
    const canvas = node;
    const ctx = canvas.getContext("2d");
    const { width, height } = canvas;
    const data = ctx.getImageData(0, 0, width, height).data;
    let nonBackground = 0;
    let minX = width;
    let minY = height;
    let maxX = -1;
    let maxY = -1;
    const background = { r: 249, g: 250, b: 251 };

    for (let y = 0; y < height; y += 1) {
      for (let x = 0; x < width; x += 1) {
        const i = (y * width + x) * 4;
        const r = data[i];
        const g = data[i + 1];
        const b = data[i + 2];
        const a = data[i + 3];
        const isBackground =
          a > 0 &&
          Math.abs(r - background.r) <= 2 &&
          Math.abs(g - background.g) <= 2 &&
          Math.abs(b - background.b) <= 2;
        if (!isBackground) {
          nonBackground += 1;
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }

    return {
      nonBackground,
      hasInk: nonBackground > 0,
      bounds:
        nonBackground > 0
          ? { minX, minY, maxX, maxY, width: maxX - minX, height: maxY - minY }
          : null,
    };
  });
}

test("multiple_strokes_preserved_in_drawing_state", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "multiple_strokes_preserved_in_drawing_state",
    testTitle: testInfo.title,
  });

  await recorder.step("mock authenticated session and upload API", async () => {
    await mockGoogleAuthenticatedSession(page);
    await mockDrawingUploadSuccess(page, uploadedGoogleDrawing);
  });

  await recorder.step("open draw page", async () => {
    await page.goto("/draw");
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeDisabled();
  });

  const box = await getBox(page);

  await recorder.step("draw horizontal line at top", async () => {
    await drawStroke(page, [
      { x: box.x + box.width * 0.15, y: box.y + box.height * 0.2 },
      { x: box.x + box.width * 0.85, y: box.y + box.height * 0.2 },
    ]);
  });

  await recorder.step("draw vertical line at center", async () => {
    await drawStroke(page, [
      { x: box.x + box.width * 0.5, y: box.y + box.height * 0.15 },
      { x: box.x + box.width * 0.5, y: box.y + box.height * 0.85 },
    ]);
  });

  await recorder.step("draw circular stroke near bottom", async () => {
    const centerX = box.x + box.width * 0.5;
    const centerY = box.y + box.height * 0.72;
    const radius = Math.min(box.width, box.height) * 0.14;
    const points = [];
    for (let i = 0; i <= 20; i += 1) {
      const angle = (Math.PI * 2 * i) / 20;
      points.push({
        x: centerX + Math.cos(angle) * radius,
        y: centerY + Math.sin(angle) * radius,
      });
    }
    await drawStroke(page, points);
  });

  await recorder.step("assert all strokes remain visible", async () => {
    const metrics = await getInkMetrics(page);
    expect(metrics.hasInk).toBe(true);
    expect(metrics.nonBackground).toBeGreaterThan(2500);
    expect(metrics.bounds.width).toBeGreaterThan(150);
    expect(metrics.bounds.height).toBeGreaterThan(150);
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeEnabled();
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:multiple_strokes_preserved_in_drawing_state");
  await recorder.save(testInfo);
});
