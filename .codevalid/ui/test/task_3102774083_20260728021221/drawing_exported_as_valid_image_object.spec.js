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

test("Completed drawing is exported as a valid digital image object", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "drawing_exported_as_valid_image_object",
    testTitle: testInfo.title,
  });

  await mockGoogleAuthenticatedSession(page);

  let uploadRequest = null;
  await page.route(appOriginRegex("/api/upload"), async (route) => {
    uploadRequest = {
      method: route.request().method(),
      headers: route.request().headers(),
      postDataBuffer: route.request().postDataBuffer(),
    };
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ ok: true, pathname: "drawings/exported.jpg" }),
    });
  });

  await recorder.step("Open draw page", async () => {
    await page.goto("/draw");
    await expect(page.locator("canvas")).toBeVisible();
  });

  await recorder.step("Draw a line and a closed shape", async () => {
    await drawStroke(page, [
      [50, 70],
      [100, 95],
      [150, 120],
      [200, 145],
      [250, 170],
    ]);
    await drawStroke(page, [
      [250, 230],
      [280, 200],
      [315, 230],
      [280, 265],
      [250, 230],
    ]);
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeEnabled();
  });

  await recorder.step("Confirm canvas exports a valid data URL before upload", async () => {
    const exportInfo = await page.locator("canvas").evaluate((canvas) => {
      const dataUrl = canvas.toDataURL("image/jpeg");
      const ctx = canvas.getContext("2d");
      const data = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
      let darkPixels = 0;
      for (let i = 0; i < data.length; i += 4) {
        const [r, g, b, a] = [data[i], data[i + 1], data[i + 2], data[i + 3]];
        if (a > 0 && r < 100 && g < 100 && b < 100) darkPixels += 1;
      }
      return {
        prefix: dataUrl.slice(0, 23),
        length: dataUrl.length,
        width: canvas.width,
        height: canvas.height,
        darkPixels,
      };
    });

    expect(exportInfo.prefix).toBe("data:image/jpeg;base64,");
    expect(exportInfo.length).toBeGreaterThan(1000);
    expect(exportInfo.width).toBeGreaterThan(0);
    expect(exportInfo.height).toBeGreaterThan(0);
    expect(exportInfo.darkPixels).toBeGreaterThan(100);
  });

  await recorder.step("Share the drawing and inspect generated upload object", async () => {
    await page.getByRole("button", { name: "Share my drawing" }).click();
    await page.waitForURL("/");

    expect(uploadRequest).not.toBeNull();
    expect(uploadRequest.method).toBe("POST");
    expect(uploadRequest.headers["content-type"]).toContain("multipart/form-data");
    expect(uploadRequest.postDataBuffer.length).toBeGreaterThan(0);
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:drawing_exported_as_valid_image_object");
  await recorder.save(testInfo);
});
