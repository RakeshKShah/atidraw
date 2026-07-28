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

test("Newly created drawing is correctly tagged with current identity provider", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "new_drawing_saved_with_correct_identity",
    testTitle: testInfo.title,
  });

  await recorder.step("Mock Google session, empty initial list, and successful upload");
  await mockGoogleAuthenticatedSession(page);
  await mockDrawingsList(page, emptyDrawingsResponse);
  await mockDrawingUploadSuccess(page, uploadedGoogleDrawing);

  await recorder.step("Open draw page and create a drawing on the canvas");
  await page.goto("/draw");
  await expect(page.getByText("Create a drawing and share it with the world!")).toBeVisible();
  await drawOnCanvas(page);

  await recorder.step("Save the drawing and assert success toast");
  await page.getByRole("button", { name: /save/i }).click();
  await expect(page.getByText("Drawing shared!")).toBeVisible();

  await recorder.step("Reload drawings API with uploaded Google drawing and verify metadata-backed UI");
  await mockDrawingsList(page, uploadedGoogleDrawingsResponse);
  await page.goto("/");
  await expect(page.getByRole("img", { name: "New Google drawing" })).toBeVisible();
  await expect(page.getByText("Google User")).toBeVisible();
  await expect(page.getByRole("img", { name: "AI image generated of New Google drawing" })).toBeVisible();

  console.log("CODEVALID_TEST_ASSERTION_OK:new_drawing_saved_with_correct_identity");
  await recorder.save(testInfo);
});
