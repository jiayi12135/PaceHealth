from datetime import date
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Path, Query, Response, status
from postgrest.exceptions import APIError as PostgrestAPIError

from app.dependencies.auth import get_current_user
from app.errors import APIError
from app.schemas.auth import AuthUser
from app.schemas.weight import WeightRecordCreate, WeightRecordResponse
from app.services.weight_service import WeightService, get_weight_service


router = APIRouter(prefix="/weights", tags=["weights"])


@router.post("", response_model=WeightRecordResponse, status_code=status.HTTP_201_CREATED)
def create_weight_record(
    payload: WeightRecordCreate,
    user: Annotated[AuthUser, Depends(get_current_user)],
    weights: Annotated[WeightService, Depends(get_weight_service)],
) -> WeightRecordResponse:
    try:
        return weights.create(user.user_id, payload)
    except PostgrestAPIError as exc:
        raise APIError(502, "Unable to save the weight record.", "WEIGHT_WRITE_FAILED") from exc


@router.get("", response_model=list[WeightRecordResponse])
def list_weight_records(
    user: Annotated[AuthUser, Depends(get_current_user)],
    weights: Annotated[WeightService, Depends(get_weight_service)],
    from_date: Annotated[date | None, Query(alias="from")] = None,
    to_date: Annotated[date | None, Query(alias="to")] = None,
) -> list[WeightRecordResponse]:
    if from_date is not None and to_date is not None and from_date > to_date:
        raise APIError(400, "The 'from' date must not be after 'to'.", "INVALID_DATE_RANGE")

    try:
        return weights.list(user.user_id, from_date, to_date)
    except PostgrestAPIError as exc:
        raise APIError(502, "Unable to load weight records.", "WEIGHT_READ_FAILED") from exc


@router.delete("/{weightLogId}", status_code=status.HTTP_204_NO_CONTENT)
def delete_weight_record(
    weight_log_id: Annotated[UUID, Path(alias="weightLogId")],
    user: Annotated[AuthUser, Depends(get_current_user)],
    weights: Annotated[WeightService, Depends(get_weight_service)],
) -> Response:
    try:
        deleted = weights.delete(user.user_id, weight_log_id)
    except PostgrestAPIError as exc:
        raise APIError(502, "Unable to delete the weight record.", "WEIGHT_DELETE_FAILED") from exc

    if not deleted:
        raise APIError(404, "Weight record was not found.", "WEIGHT_NOT_FOUND")

    return Response(status_code=status.HTTP_204_NO_CONTENT)
