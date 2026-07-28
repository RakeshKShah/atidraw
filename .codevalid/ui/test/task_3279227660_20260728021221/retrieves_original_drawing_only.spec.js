import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { mockDrawingsList } from "../../helpers/mock-api.js";
import { originalDrawingOnlyResponse } from "../../mock/mock-data.js";

test("Original drawing-only creation is retrieved and displayed", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "retrieves_original_drawing_only",
    testTitle: "Original drawing-only creation is retrieved and displayed",
  });

  await recorder.step("Mock GET /api/drawings with drawing-only payload", async () => {
    await mockDrawingsList(page, originalDrawingOnlyResponse);
  });

  await recorder.step("Navigate to homepage", async () => {
    await page.goto("/");
  });

  await recorder.step("Verify drawing preview and creator name are rendered", async () => {
    await expect(page.getByText("John")).toBeVisible();
    await expect(page.getByAltText("Original-only drawing")).toBeVisible();
  });

  await recorder.step("Verify no AI overlay image is rendered for drawing-only item", async () => {
    await expect(page.getByAltText("AI image generated of Original-only drawing")).toHaveCount(0);
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:retrieves_original_drawing_only");
  await recorder.save(testInfo);
});
