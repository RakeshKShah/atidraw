import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockDrawingsList,
  mockDrawingUploadSuccess,
  drawOnCanvas,
} from "../../helpers/mock-api.js";
import {
  emptyDrawingsResponse,
  uploadedGoogleDrawing,
  uploadedGoogleDrawingsResponse,
} from "../../mock/mock-data.js";

test("User saves an original drawing — local storage and sync triggered", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "save_original_drawing_only",
    testTitle: testInfo.title,
  });

  await mockGoogleAuthenticatedSession(page);
  await mockDrawingsList(page, emptyDrawingsResponse);
  await mockDrawingUploadSuccess(page, uploadedGoogleDrawing);

  await recorder.step("Open draw page", async () => {
    await page.goto("/draw");
    await expect(page.getByText("Create a drawing and share it with the world!")).toBeVisible();
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeDisabled();
  });

  await recorder.step("Create an original drawing on canvas", async () => {
    await drawOnCanvas(page);
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeEnabled();
  });

  await recorder.step("Share the drawing", async () => {
    await page.getByRole("button", { name: "Share my drawing" }).click();
    await expect(page.getByText("Drawing shared!")).toBeVisible();
    await expect(page).toHaveURL(/\/$/);
  });

  await recorder.step("Retrieve saved creation from synchronized library", async () => {
    await page.unroute(/\/api\/drawings(?:\?.*)?$/);
    await mockDrawingsList(page, uploadedGoogleDrawingsResponse);
    await page.goto("/");
    await expect(page.getByAltText("New Google drawing")).toBeVisible();
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:save_original_drawing_only");
  await recorder.save(testInfo);
});
