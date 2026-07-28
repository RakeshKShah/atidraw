import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockDrawingUploadSuccess,
} from "../../helpers/mock-api.js";
import { uploadedGoogleDrawing } from "../../mock/mock-data.js";

async function getCanvasBox(page) {
  const canvas = page.locator("canvas");
  await expect(canvas).toBeVisible();
  const box = await canvas.boundingBox();
  if (!box) throw new Error("Canvas bounding box unavailable");
  return box;
}

async function drawPoints(page, points, holdAtEndMs = 0) {
  await page.mouse.move(points[0].x, points[0].y);
  await page.mouse.down();
  for (const point of points.slice(1)) {
    await page.mouse.move(point.x, point.y, { steps: 6 });
  }
  if (holdAtEndMs > 0) {
    await page.waitForTimeout(holdAtEndMs);
  }
  await page.mouse.up();
}

async function inkStats(page) {
  return await page.locator("canvas").evaluate((node) => {
    const canvas = node;
    const ctx = canvas.getContext("2d");
    const { width, height } = canvas;
    const data = ctx.getImageData(0, 0, width, height).data;
    let nonBackground = 0;
    const background = { r: 249, g: 250, b: 251 };
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
      if (!isBackground) nonBackground += 1;
    }
    return { nonBackground, hasInk: nonBackground > 0 };
  });
}

test("drawing_state_maintained_during_interaction", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "drawing_state_maintained_during_interaction",
    testTitle: testInfo.title,
  });

  await recorder.step("setup authenticated session", async () => {
    await mockGoogleAuthenticatedSession(page);
    await mockDrawingUploadSuccess(page, uploadedGoogleDrawing);
  });

  await recorder.step("visit draw page", async () => {
    await page.goto("/draw");
    await expect(page.getByText("Create a drawing and share it with the world!")).toBeVisible();
  });

  const box = await getCanvasBox(page);

  await recorder.step("draw overlapping pattern continuously", async () => {
    const points = [];
    for (let i = 0; i <= 40; i += 1) {
      const progress = i / 40;
      points.push({
        x: box.x + box.width * (0.15 + 0.7 * progress),
        y: box.y + box.height * (0.5 + Math.sin(progress * Math.PI * 6) * 0.22),
      });
    }
    await drawPoints(page, points, 400);
  });

  let initialInk = 0;
  await recorder.step("capture ink after first long interaction", async () => {
    const stats = await inkStats(page);
    initialInk = stats.nonBackground;
    expect(stats.hasInk).toBe(true);
    expect(initialInk).toBeGreaterThan(2000);
  });

  await recorder.step("pause and resume with second shape", async () => {
    await page.waitForTimeout(2000);
    await drawPoints(page, [
      { x: box.x + box.width * 0.25, y: box.y + box.height * 0.25 },
      { x: box.x + box.width * 0.75, y: box.y + box.height * 0.25 },
      { x: box.x + box.width * 0.5, y: box.y + box.height * 0.75 },
      { x: box.x + box.width * 0.25, y: box.y + box.height * 0.25 },
    ]);
  });

  await recorder.step("assert prior drawing remains and new stroke adds ink", async () => {
    const stats = await inkStats(page);
    expect(stats.hasInk).toBe(true);
    expect(stats.nonBackground).toBeGreaterThan(initialInk);
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeEnabled();
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:drawing_state_maintained_during_interaction");
  await recorder.save(testInfo);
});
