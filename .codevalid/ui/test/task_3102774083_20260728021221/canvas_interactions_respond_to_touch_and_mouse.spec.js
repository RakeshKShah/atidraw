import { test, expect } from "@playwright/test";
import { devices } from "@playwright/test";
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

test("canvas_interactions_respond_to_touch_and_mouse", async ({ browser }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "canvas_interactions_respond_to_touch_and_mouse",
    testTitle: testInfo.title,
  });

  const mouseContext = await browser.newContext();
  const mousePage = await mouseContext.newPage();
  const touchContext = await browser.newContext({
    ...devices["iPhone 13"],
    isMobile: true,
    hasTouch: true,
  });
  const touchPage = await touchContext.newPage();

  try {
    await recorder.step("draw with mouse in desktop context", async () => {
      await mockGoogleAuthenticatedSession(mousePage);
      await mockDrawingUploadSuccess(mousePage, uploadedGoogleDrawing);
      await mousePage.goto("/draw");
      const canvas = mousePage.locator("canvas");
      await expect(canvas).toBeVisible();
      const box = await canvas.boundingBox();
      if (!box) throw new Error("Mouse canvas bounding box unavailable");
      await mousePage.mouse.move(box.x + box.width * 0.2, box.y + box.height * 0.25);
      await mousePage.mouse.down();
      await mousePage.mouse.move(box.x + box.width * 0.8, box.y + box.height * 0.65, { steps: 14 });
      await mousePage.mouse.up();
      expect(await getInkCount(mousePage)).toBeGreaterThan(500);
    });

    await recorder.step("draw with touch in mobile context", async () => {
      await mockGoogleAuthenticatedSession(touchPage);
      await mockDrawingUploadSuccess(touchPage, uploadedGoogleDrawing);
      await touchPage.goto("/draw");
      const canvas = touchPage.locator("canvas");
      await expect(canvas).toBeVisible();
      const box = await canvas.boundingBox();
      if (!box) throw new Error("Touch canvas bounding box unavailable");
      await touchPage.touchscreen.tap(box.x + box.width * 0.2, box.y + box.height * 0.2);
      await touchPage.touchscreen.tap(box.x + box.width * 0.35, box.y + box.height * 0.35);
      await touchPage.touchscreen.tap(box.x + box.width * 0.5, box.y + box.height * 0.5);
      await touchPage.touchscreen.tap(box.x + box.width * 0.65, box.y + box.height * 0.65);
      expect(await getInkCount(touchPage)).toBeGreaterThan(0);
    });
  } finally {
    await mouseContext.close();
    await touchContext.close();
  }

  console.log("CODEVALID_TEST_ASSERTION_OK:canvas_interactions_respond_to_touch_and_mouse");
  await recorder.save(testInfo);
});
