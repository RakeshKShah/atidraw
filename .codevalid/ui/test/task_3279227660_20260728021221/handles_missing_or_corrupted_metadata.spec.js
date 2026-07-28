import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { mockDrawingsList } from "../../helpers/mock-api.js";
import { malformedMetadataResponse } from "../../mock/mock-data.js";

test("UI gracefully handles missing or malformed custom metadata", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "handles_missing_or_corrupted_metadata",
    testTitle: "UI gracefully handles missing or malformed custom metadata",
  });

  const pageErrors = [];
  page.on("pageerror", (error) => {
    pageErrors.push(error.message);
  });

  await recorder.step("Mock GET /api/drawings with malformed metadata payload", async () => {
    await mockDrawingsList(page, malformedMetadataResponse);
  });

  await recorder.step("Navigate to homepage", async () => {
    await page.goto("/");
  });

  await recorder.step("Verify artwork still renders with pathname fallback alt text", async () => {
    await expect(page.getByAltText("drawings/malformed-metadata.png")).toBeVisible();
  });

  await recorder.step("Verify no AI overlay image is shown when aiImage metadata is absent", async () => {
    await expect(page.locator('img[alt^="AI image generated of "]')).toHaveCount(0);
  });

  await recorder.step("Verify the page remains stable without uncaught JavaScript errors", async () => {
    expect(pageErrors).toEqual([]);
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:handles_missing_or_corrupted_metadata");
  await recorder.save(testInfo);
});
