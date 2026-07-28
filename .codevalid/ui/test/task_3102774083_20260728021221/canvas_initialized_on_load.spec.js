import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockDrawingUploadSuccess,
} from "../../helpers/mock-api.js";
import { uploadedGoogleDrawing } from "../../mock/mock-data.js";

function appUrlRegex(pathname) {
  return new RegExp(`^https?:\\/\\/[^/]+${pathname.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(?:\\?.*)?$`);
}

test("Drawing canvas is properly initialized on page load", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "canvas_initialized_on_load",
    testTitle: testInfo.title,
  });

  await mockGoogleAuthenticatedSession(page);
  await mockDrawingUploadSuccess(page, uploadedGoogleDrawing);

  const pageErrors = [];
  page.on("pageerror", (error) => pageErrors.push(error.message));

  await recorder.step("Navigate to draw page", async () => {
    await page.goto("/draw");
  });

  await recorder.step("Verify signature pad canvas and controls render", async () => {
    const canvas = page.locator("canvas");
    await expect(canvas).toBeVisible();
    await expect(page.getByRole("button", { name: "Undo" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Clear" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeVisible();
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeDisabled();
  });

  await recorder.step("Verify canvas dimensions and clear background readiness", async () => {
    const canvasMetrics = await page.locator("canvas").evaluate((canvas) => {
      const rect = canvas.getBoundingClientRect();
      const ctx = canvas.getContext("2d");
      const sample = ctx.getImageData(5, 5, 1, 1).data;
      return {
        clientWidth: rect.width,
        clientHeight: rect.height,
        internalWidth: canvas.width,
        internalHeight: canvas.height,
        pixel: Array.from(sample),
      };
    });

    expect(canvasMetrics.clientWidth).toBeGreaterThan(0);
    expect(canvasMetrics.clientHeight).toBeGreaterThan(0);
    expect(canvasMetrics.internalWidth).toBeGreaterThanOrEqual(Math.round(canvasMetrics.clientWidth));
    expect(canvasMetrics.internalHeight).toBeGreaterThanOrEqual(Math.round(canvasMetrics.clientHeight));
    expect(canvasMetrics.pixel[0]).toBeGreaterThan(200);
    expect(canvasMetrics.pixel[1]).toBeGreaterThan(200);
    expect(canvasMetrics.pixel[2]).toBeGreaterThan(200);
  });

  await recorder.step("Verify page initializes without JavaScript errors", async () => {
    expect(pageErrors).toEqual([]);
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:canvas_initialized_on_load");
  await recorder.save(testInfo);
});
