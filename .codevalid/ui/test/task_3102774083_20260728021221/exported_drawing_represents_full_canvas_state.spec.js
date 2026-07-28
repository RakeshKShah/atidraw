import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { mockGoogleAuthenticatedSession } from "../../helpers/mock-api.js";

async function getBox(page) {
  const canvas = page.locator("canvas");
  await expect(canvas).toBeVisible();
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

test("exported_drawing_represents_full_canvas_state", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "exported_drawing_represents_full_canvas_state",
    testTitle: testInfo.title,
  });

  let uploadedByteLength = 0;

  await recorder.step("mock authenticated session and upload endpoint", async () => {
    await mockGoogleAuthenticatedSession(page);
    await page.route(/^https?:\/\/[^/]+\/api\/upload(?:\?.*)?$/, async (route) => {
      const data = route.request().postDataBuffer();
      uploadedByteLength = data ? data.length : 0;
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ ok: true, pathname: "drawings/full-state.jpg" }),
      });
    });
  });

  await recorder.step("open drawing page", async () => {
    await page.goto("/draw");
    await expect(page.getByText("Create a drawing and share it with the world!")).toBeVisible();
  });

  const box = await getBox(page);

  await recorder.step("draw a detailed multi-stroke sketch", async () => {
    await drawPath(page, [
      { x: box.x + box.width * 0.2, y: box.y + box.height * 0.7 },
      { x: box.x + box.width * 0.5, y: box.y + box.height * 0.35 },
      { x: box.x + box.width * 0.8, y: box.y + box.height * 0.7 },
    ]);
    await drawPath(page, [
      { x: box.x + box.width * 0.28, y: box.y + box.height * 0.7 },
      { x: box.x + box.width * 0.28, y: box.y + box.height * 0.35 },
      { x: box.x + box.width * 0.72, y: box.y + box.height * 0.35 },
      { x: box.x + box.width * 0.72, y: box.y + box.height * 0.7 },
      { x: box.x + box.width * 0.28, y: box.y + box.height * 0.7 },
    ]);
    await drawPath(page, [
      { x: box.x + box.width * 0.38, y: box.y + box.height * 0.5 },
      { x: box.x + box.width * 0.38, y: box.y + box.height * 0.6 },
      { x: box.x + box.width * 0.48, y: box.y + box.height * 0.6 },
      { x: box.x + box.width * 0.48, y: box.y + box.height * 0.5 },
      { x: box.x + box.width * 0.38, y: box.y + box.height * 0.5 },
    ]);
    await drawPath(page, [
      { x: box.x + box.width * 0.56, y: box.y + box.height * 0.5 },
      { x: box.x + box.width * 0.56, y: box.y + box.height * 0.6 },
      { x: box.x + box.width * 0.66, y: box.y + box.height * 0.6 },
      { x: box.x + box.width * 0.66, y: box.y + box.height * 0.5 },
      { x: box.x + box.width * 0.56, y: box.y + box.height * 0.5 },
    ]);
  });

  await recorder.step("share drawing and validate full image object was uploaded", async () => {
    await page.getByRole("button", { name: "Share my drawing" }).click();
    expect(uploadedByteLength).toBeGreaterThan(2000);
    await expect(page.getByText("Drawing shared!")).toBeVisible();
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:exported_drawing_represents_full_canvas_state");
  await recorder.save(testInfo);
});
