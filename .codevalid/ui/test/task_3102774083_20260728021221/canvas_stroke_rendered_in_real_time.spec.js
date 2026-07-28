import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockDrawingUploadSuccess,
} from "../../helpers/mock-api.js";
import { uploadedGoogleDrawing } from "../../mock/mock-data.js";

async function getCanvasAndContext(page) {
  const canvas = page.locator("canvas");
  await expect(canvas).toBeVisible();
  const handle = await canvas.elementHandle();
  if (!handle) throw new Error("Canvas element handle unavailable");
  return { canvas, handle };
}

async function getCanvasBoundingBox(canvas) {
  const box = await canvas.boundingBox();
  if (!box) throw new Error("Canvas bounding box unavailable");
  return box;
}

async function drawPath(page, points) {
  await page.mouse.move(points[0].x, points[0].y);
  await page.mouse.down();
  for (const point of points.slice(1)) {
    await page.mouse.move(point.x, point.y, { steps: 8 });
  }
  await page.mouse.up();
}

async function getInkMetrics(page) {
  const canvas = page.locator("canvas");
  return await canvas.evaluate((node) => {
    const canvasEl = node;
    const ctx = canvasEl.getContext("2d");
    const { width, height } = canvasEl;
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

test("canvas_stroke_rendered_in_real_time", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "canvas_stroke_rendered_in_real_time",
    testTitle: testInfo.title,
  });

  await recorder.step("mock authenticated drawing page", async () => {
    await mockGoogleAuthenticatedSession(page);
    await mockDrawingUploadSuccess(page, uploadedGoogleDrawing);
  });

  await recorder.step("open draw page", async () => {
    await page.goto("/draw");
    await expect(page.getByText("Create a drawing and share it with the world!")).toBeVisible();
  });

  const { canvas } = await getCanvasAndContext(page);
  const box = await getCanvasBoundingBox(canvas);

  await recorder.step("verify canvas starts empty", async () => {
    const metrics = await getInkMetrics(page);
    expect(metrics.hasInk).toBe(false);
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeDisabled();
  });

  await recorder.step("draw a curved stroke across canvas", async () => {
    const points = [
      { x: box.x + box.width * 0.15, y: box.y + box.height * 0.2 },
      { x: box.x + box.width * 0.3, y: box.y + box.height * 0.35 },
      { x: box.x + box.width * 0.45, y: box.y + box.height * 0.5 },
      { x: box.x + box.width * 0.6, y: box.y + box.height * 0.55 },
      { x: box.x + box.width * 0.8, y: box.y + box.height * 0.7 },
    ];
    await drawPath(page, points);
  });

  await recorder.step("assert stroke visible immediately after mouse up", async () => {
    const metrics = await getInkMetrics(page);
    expect(metrics.hasInk).toBe(true);
    expect(metrics.nonBackground).toBeGreaterThan(500);
    expect(metrics.bounds.minX).toBeLessThan(metrics.bounds.maxX);
    expect(metrics.bounds.minY).toBeLessThan(metrics.bounds.maxY);
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeEnabled();
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:canvas_stroke_rendered_in_real_time");
  await recorder.save(testInfo);
});
